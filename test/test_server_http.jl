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
    # Create server with environment variables set
    server = withenv(
        "TESTPICKER_MCP_TRANSPORT" => "http",
        "TESTPICKER_MCP_HOST" => host,
        "TESTPICKER_MCP_PORT" => string(port),
    ) do
        TestPickerMCPServer.create_server(pkg_dir)
    end

    # Start server on a background thread
    server_task = Threads.@spawn begin
        try
            start!(server; transport = server.transport)
        catch e
            @warn "Server error: $e"
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
            @warn "Error stopping server: $e"
        end
        # Clean up
        TestPickerMCPServer.SERVER_PKG[] = nothing
        sleep(0.5)
    end
end

"""
Helper function to send an MCP tool call via HTTP.
"""
function call_mcp_tool(
    host::String,
    port::Integer,
    tool_name::String,
    params::Dict{String,Any} = Dict{String,Any}(),
)
    url = "http://$host:$port/mcp/call"

    # MCP request format
    request_body =
        Dict("jsonrpc" => "2.0", "id" => "1", "method" => tool_name, "params" => params)

    try
        response = HTTP.post(
            url,
            ["Content-Type" => "application/json"],
            JSON.json(request_body);
            timeout = 5,
            retry = false,
        )

        if response.status == 200
            return JSON.parse(String(response.body))
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
                response = call_mcp_tool(host, port, "list_testfiles", Dict{String,Any}())

                @test haskey(response, "result")
                result = response["result"]
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
                response = call_mcp_tool(host, port, "list_testblocks", Dict{String,Any}())

                @test haskey(response, "result")
                result = response["result"]
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
                response = call_mcp_tool(
                    host,
                    port,
                    "list_testfiles",
                    Dict{String,Any}("query" => "basic"),
                )

                @test haskey(response, "result")
                result = response["result"]
                @test result["count"] == 1
                @test "test_basic.jl" in result["files"]
            end
        end
    end

    @testset "Filter test blocks with file query via HTTP" begin
        with_server(dummy_pkg_path; port = 8768) do host, port
            redirect_stderr(devnull) do
                response = call_mcp_tool(
                    host,
                    port,
                    "list_testblocks",
                    Dict{String,Any}("file_query" => "math"),
                )

                @test haskey(response, "result")
                result = response["result"]
                @test result["count"] == 13
            end
        end
    end

    @testset "Run all tests via HTTP" begin
        with_server(dummy_pkg_path; port = 8769) do host, port
            redirect_stderr(devnull) do
                response = call_mcp_tool(host, port, "run_all_tests", Dict{String,Any}())

                @test haskey(response, "result")
                result = response["result"]
                @test haskey(result, "status")
                @test result["status"] in ["completed", "failed"]
            end
        end
    end

    @testset "Run specific test file via HTTP" begin
        with_server(dummy_pkg_path; port = 8770) do host, port
            redirect_stderr(devnull) do
                response = call_mcp_tool(
                    host,
                    port,
                    "run_testfiles",
                    Dict{String,Any}("query" => "test_basic"),
                )

                @test haskey(response, "result")
                result = response["result"]
                @test haskey(result, "status")
                @test result["status"] in ["completed", "failed"]
            end
        end
    end

    @testset "Run specific test block via HTTP" begin
        with_server(dummy_pkg_path; port = 8771) do host, port
            redirect_stderr(devnull) do
                response = call_mcp_tool(
                    host,
                    port,
                    "run_testblocks",
                    Dict{String,Any}("file_query" => "basic", "testset_query" => "String"),
                )

                @test haskey(response, "result")
                result = response["result"]
                @test haskey(result, "status")
                @test result["status"] in ["completed", "failed"]
            end
        end
    end

    @testset "Get test results via HTTP" begin
        with_server(dummy_pkg_path; port = 8772) do host, port
            redirect_stderr(devnull) do
                # First run a test
                call_mcp_tool(
                    host,
                    port,
                    "run_testfiles",
                    Dict{String,Any}("query" => "test_failures"),
                )

                # Then get results
                response = call_mcp_tool(host, port, "get_testresults", Dict{String,Any}())

                @test haskey(response, "result")
                result = response["result"]
                @test haskey(result, "count")
            end
        end
    end

    @testset "Parameter validation via HTTP" begin
        with_server(dummy_pkg_path; port = 8773) do host, port
            redirect_stderr(devnull) do
                # Test run_testfiles without required query parameter
                response = call_mcp_tool(host, port, "run_testfiles", Dict{String,Any}())

                @test haskey(response, "error")
                @test contains(response["error"], "query required")

                # Test run_testblocks without required testset_query parameter
                response = call_mcp_tool(
                    host,
                    port,
                    "run_testblocks",
                    Dict{String,Any}("file_query" => "basic"),
                )

                @test haskey(response, "error")
                @test contains(response["error"], "testset_query required")
            end
        end
    end

    @testset "Multiple sequential operations via HTTP" begin
        with_server(dummy_pkg_path; port = 8774) do host, port
            redirect_stderr(devnull) do
                # Step 1: List files
                response = call_mcp_tool(host, port, "list_testfiles", Dict{String,Any}())
                @test response["result"]["count"] == 4

                # Step 2: List testblocks
                response = call_mcp_tool(host, port, "list_testblocks", Dict{String,Any}())
                @test response["result"]["count"] == 34

                # Step 3: Run a test file
                response = call_mcp_tool(
                    host,
                    port,
                    "run_testfiles",
                    Dict{String,Any}("query" => "test_basic"),
                )
                @test response["result"]["status"] in ["completed", "failed"]

                # Step 4: Get results
                response = call_mcp_tool(host, port, "get_testresults", Dict{String,Any}())
                @test haskey(response["result"], "count")
            end
        end
    end
end
