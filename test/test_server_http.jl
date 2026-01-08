using TestPickerMCPServer
using ModelContextProtocol
using Test
using JSON
using Pkg
using HTTP
using HTTP.Sockets

"""
Helper function to start the server on a background thread and interact with it via HTTP.
"""
function with_server(
    f,
    pkg_dir::String = pwd();
    host::String = "127.0.0.1",
    port::Integer = 8765,
)
    # Create server with environment variables set, and redirect stderr to suppress JSON-RPC notifications
    server = redirect_stderr(devnull) do
        withenv(
            "TESTPICKER_MCP_TRANSPORT" => "http",
            "TESTPICKER_MCP_HOST" => host,
            "TESTPICKER_MCP_PORT" => string(port),
        ) do
            TestPickerMCPServer.create_server(pkg_dir)
        end
    end

    # Start server on a background thread with stderr redirected
    server_task = Threads.@spawn begin
        redirect_stderr(devnull) do
            try
                start!(server; transport = server.transport)
            catch e
                # Silently ignore errors during shutdown
            end
        end
    end

    # Give server time to fully initialize
    sleep(2)

    try
        f(host, port)
    finally
        # Stop the server gracefully
        try
            ModelContextProtocol.stop!(server)
        catch e
            # Silently ignore errors during shutdown
        end
        # Clean up
        TestPickerMCPServer.SERVER_PKG[] = nothing
        sleep(0.5)
    end
end

"""
Helper function to initialize MCP session via HTTP.
Returns the session ID needed for subsequent calls.
"""
function initialize_mcp_session(host::String, port::Integer)
    url = "http://$host:$port/"
    
    request_body = Dict(
        "jsonrpc" => "2.0",
        "method" => "initialize",
        "params" => Dict(
            "protocolVersion" => "2025-06-18",
            "capabilities" => Dict(),
            "clientInfo" => Dict("name" => "test-client", "version" => "1.0.0")
        ),
        "id" => 1
    )
    
    response = HTTP.post(
        url,
        [
            "Content-Type" => "application/json",
            "MCP-Protocol-Version" => "2025-06-18",
            "Accept" => "application/json, text/event-stream"
        ],
        JSON.json(request_body);
        timeout = 10,
        retry = false,
    )
    
    if response.status == 200
        session_id = HTTP.header(response, "Mcp-Session-Id", "")
        if isempty(session_id)
            error("No session ID returned from initialization")
        end
        return session_id
    else
        error("HTTP error during initialization: $(response.status)")
    end
end

"""
Helper to parse MCP response content from tool calls.
Returns the parsed JSON from the content field.
"""
function parse_mcp_response(response)
    @assert haskey(response, "content") "Response missing content field"
    content = response["content"][1]
    @assert content["type"] == "text" "Expected text content"
    return JSON.parse(content["text"])
end

# Atomic counter for request IDs to ensure uniqueness
const REQUEST_ID_COUNTER = Threads.Atomic{Int}(0)

"""
Helper function to send an MCP tool call via HTTP.
"""
function call_mcp_tool(
    host::String,
    port::Integer,
    session_id::AbstractString,
    tool_name::String,
    params::Dict{String,Any} = Dict{String,Any}(),
)
    url = "http://$host:$port/"

    # Use atomic counter for guaranteed unique request IDs
    request_id = string(Threads.atomic_add!(REQUEST_ID_COUNTER, 1))

    # MCP tools/call request format
    request_body = Dict(
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "params" => Dict(
            "name" => tool_name,
            "arguments" => params
        ),
        "id" => request_id
    )

    try
        response = HTTP.post(
            url,
            [
                "Content-Type" => "application/json",
                "MCP-Protocol-Version" => "2025-06-18",
                "Mcp-Session-Id" => session_id,
                "Accept" => "application/json, text/event-stream"
            ],
            JSON.json(request_body);
            timeout = 10,
            retry = false,
        )

        if response.status == 200
            result = JSON.parse(String(response.body))
            # Check for JSON-RPC error response
            if haskey(result, "error")
                return Dict("error" => result["error"]["message"])
            end
            # Return the result field from the JSON-RPC response
            if haskey(result, "result")
                return result["result"]
            else
                return result
            end
        else
            error("HTTP error: $(response.status)")
        end
    catch e
        error("Failed to call $tool_name: $(string(e))")
    end
end

@testset "HTTP Server Tests with DummyPackage" begin
    dummy_pkg_path =
        abspath(joinpath(pkgdir(TestPickerMCPServer), "test/fixtures/DummyPackage"))

    @testset "List test files via HTTP" begin
        with_server(dummy_pkg_path; port = 8765) do host, port
            redirect_stderr(devnull) do
                session_id = initialize_mcp_session(host, port)
                response = call_mcp_tool(host, port, session_id, "list_testfiles", Dict{String,Any}())

                result = parse_mcp_response(response)
                @test result["count"] == 4
                @test "test_basic.jl" in result["files"]
                @test "test_math.jl" in result["files"]
                @test "test_failures.jl" in result["files"]
            end
        end
    end

    @testset "List test blocks via HTTP" begin
        with_server(dummy_pkg_path; port = 8766) do host, port
            redirect_stderr(devnull) do
                session_id = initialize_mcp_session(host, port)
                response = call_mcp_tool(host, port, session_id, "list_testblocks", Dict{String,Any}())

                result = parse_mcp_response(response)
                @test result["count"] == 34
                @test isa(result["testblocks"], Vector)
                @test length(result["testblocks"]) == 34

                # Check structure of testblocks
                for block in result["testblocks"]
                    @test haskey(block, "label")
                    @test haskey(block, "file")
                    @test haskey(block, "line_start")
                    @test haskey(block, "line_end")
                end
            end
        end
    end

    @testset "Filter test files with query via HTTP" begin
        with_server(dummy_pkg_path; port = 8767) do host, port
            redirect_stderr(devnull) do
                session_id = initialize_mcp_session(host, port)
                response = call_mcp_tool(
                    host,
                    port,
                    session_id,
                    "list_testfiles",
                    Dict{String,Any}("query" => "basic"),
                )

                result = parse_mcp_response(response)
                @test result["count"] == 1
                @test "test_basic.jl" in result["files"]
            end
        end
    end

    @testset "Filter test blocks with file query via HTTP" begin
        with_server(dummy_pkg_path; port = 8768) do host, port
            redirect_stderr(devnull) do
                session_id = initialize_mcp_session(host, port)
                response = call_mcp_tool(
                    host,
                    port,
                    session_id,
                    "list_testblocks",
                    Dict{String,Any}("file_query" => "math"),
                )

                result = parse_mcp_response(response)
                @test result["count"] == 13
            end
        end
    end

    @testset "Run all tests via HTTP" begin
        with_server(dummy_pkg_path; port = 8769) do host, port
            redirect_stderr(devnull) do
                session_id = initialize_mcp_session(host, port)
                response = call_mcp_tool(host, port, session_id, "run_all_tests", Dict{String,Any}())

                result = parse_mcp_response(response)
                @test haskey(result, "status")
                @test result["status"] in ["completed", "failed"]
            end
        end
    end

    @testset "Run specific test file via HTTP" begin
        with_server(dummy_pkg_path; port = 8770) do host, port
            redirect_stderr(devnull) do
                session_id = initialize_mcp_session(host, port)
                response = call_mcp_tool(
                    host,
                    port,
                    session_id,
                    "run_testfiles",
                    Dict{String,Any}("query" => "test_basic"),
                )

                result = parse_mcp_response(response)
                @test haskey(result, "status")
                @test result["status"] in ["completed", "failed"]
            end
        end
    end

    @testset "Run specific test block via HTTP" begin
        with_server(dummy_pkg_path; port = 8771) do host, port
            redirect_stderr(devnull) do
                session_id = initialize_mcp_session(host, port)
                response = call_mcp_tool(
                    host,
                    port,
                    session_id,
                    "run_testblocks",
                    Dict{String,Any}("file_query" => "basic", "testset_query" => "String"),
                )

                result = parse_mcp_response(response)
                @test haskey(result, "status")
                @test result["status"] in ["completed", "failed"]
            end
        end
    end

    @testset "Get test results via HTTP" begin
        with_server(dummy_pkg_path; port = 8772) do host, port
            redirect_stderr(devnull) do
                session_id = initialize_mcp_session(host, port)
                # First run a test
                call_mcp_tool(
                    host,
                    port,
                    session_id,
                    "run_testfiles",
                    Dict{String,Any}("query" => "test_failures"),
                )

                # Then get results
                response = call_mcp_tool(host, port, session_id, "get_testresults", Dict{String,Any}())

                result = parse_mcp_response(response)
                @test haskey(result, "count")
            end
        end
    end

    @testset "Parameter validation via HTTP" begin
        with_server(dummy_pkg_path; port = 8773) do host, port
            redirect_stderr(devnull) do
                session_id = initialize_mcp_session(host, port)
                # Test run_testfiles without required query parameter
                response = call_mcp_tool(host, port, session_id, "run_testfiles", Dict{String,Any}())

                result = parse_mcp_response(response)
                @test haskey(result, "error")
                @test contains(result["error"], "query required")

                # Test run_testblocks without required testset_query parameter
                response = call_mcp_tool(
                    host,
                    port,
                    session_id,
                    "run_testblocks",
                    Dict{String,Any}("file_query" => "basic"),
                )

                result = parse_mcp_response(response)
                @test haskey(result, "error")
                @test contains(result["error"], "testset_query required")
            end
        end
    end

    @testset "Multiple sequential operations via HTTP" begin
        with_server(dummy_pkg_path; port = 8774) do host, port
            redirect_stderr(devnull) do
                session_id = initialize_mcp_session(host, port)
                # Step 1: List files
                response = call_mcp_tool(host, port, session_id, "list_testfiles", Dict{String,Any}())
                result = parse_mcp_response(response)
                @test result["count"] == 4

                # Step 2: List testblocks
                response = call_mcp_tool(host, port, session_id, "list_testblocks", Dict{String,Any}())
                result = parse_mcp_response(response)
                @test result["count"] == 34

                # Step 3: Run a test file
                response = call_mcp_tool(
                    host,
                    port,
                    session_id,
                    "run_testfiles",
                    Dict{String,Any}("query" => "test_basic"),
                )
                result = parse_mcp_response(response)
                @test result["status"] in ["completed", "failed"]

                # Step 4: Get results
                response = call_mcp_tool(host, port, session_id, "get_testresults", Dict{String,Any}())
                result = parse_mcp_response(response)
                @test haskey(result, "count")
            end
        end
    end
end
