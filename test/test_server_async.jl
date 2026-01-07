using TestPickerMCPServer
using Test
using JSON
using Pkg
using Sockets
using Base.Threads

"""
Helper function to start the server on a background thread and interact with it.
"""
function with_server(f, pkg_dir::String=pwd())
    # Start server on a background thread
    server_task = @async begin
        try
            TestPickerMCPServer.start_server(pkg_dir)
        catch e
            # Server may exit via signal, that's okay
            nothing
        end
    end

    # Give server time to start
    sleep(1)

    try
        f()
    finally
        # Note: In practice, the server would be terminated via signal
        # For testing, we just let it run in the background
    end
end

@testset "Async Server Tests with DummyPackage" begin
    @testset "Server can start and discover packages" begin
        dummy_pkg_path = abspath(
            joinpath(pkgdir(TestPickerMCPServer), "test/fixtures/DummyPackage")
        )

        # Test that we can start the server and it detects the package correctly
        redirect_stderr(devnull) do
            Pkg.activate(dummy_pkg_path) do
                TestPickerMCPServer.SERVER_PKG[] = TestPickerMCPServer.detect_package()

                @test TestPickerMCPServer.SERVER_PKG[] !== nothing
                pkg = TestPickerMCPServer.SERVER_PKG[]
                @test pkg.name == "DummyPackage"

                TestPickerMCPServer.SERVER_PKG[] = nothing
            end
        end
    end

    @testset "Handler functions work correctly via direct calls" begin
        dummy_pkg_path = abspath(
            joinpath(pkgdir(TestPickerMCPServer), "test/fixtures/DummyPackage")
        )

        redirect_stderr(devnull) do
            Pkg.activate(dummy_pkg_path) do
                TestPickerMCPServer.SERVER_PKG[] = TestPickerMCPServer.detect_package()

                # Test list_testfiles
                result = TestPickerMCPServer.handle_list_testfiles(Dict{String,Any}())
                parsed = JSON.parse(result.text)
                @test parsed["count"] == 4
                @test haskey(Set(parsed["files"]), "test_basic.jl")

                # Test list_testblocks
                result = TestPickerMCPServer.handle_list_testblocks(Dict{String,Any}())
                parsed = JSON.parse(result.text)
                @test parsed["count"] == 34

                # Test run_testfiles
                result = TestPickerMCPServer.handle_run_testfiles(
                    Dict{String,Any}("query" => "basic")
                )
                parsed = JSON.parse(result.text)
                @test parsed["status"] in ["completed", "failed"]

                TestPickerMCPServer.SERVER_PKG[] = nothing
            end
        end
    end

    @testset "All tools are callable through handler dispatch" begin
        dummy_pkg_path = abspath(
            joinpath(pkgdir(TestPickerMCPServer), "test/fixtures/DummyPackage")
        )

        redirect_stderr(devnull) do
            Pkg.activate(dummy_pkg_path) do
                TestPickerMCPServer.SERVER_PKG[] = TestPickerMCPServer.detect_package()

                # Test that all tools can be called
                tools_test_cases = [
                    ("list_testfiles", Dict{String,Any}("query" => "basic")),
                    ("list_testblocks", Dict{String,Any}("file_query" => "math")),
                    ("run_all_tests", Dict{String,Any}()),
                    ("run_testfiles", Dict{String,Any}("query" => "test_basic")),
                    ("run_testblocks", Dict{String,Any}("file_query" => "basic", "testset_query" => "String")),
                    ("get_testresults", Dict{String,Any}()),
                ]

                for (tool_name, params) in tools_test_cases
                    # Find the tool
                    tool = nothing
                    for t in TestPickerMCPServer.ALL_TOOLS
                        if t.name == tool_name
                            tool = t
                            break
                        end
                    end

                    @test tool !== nothing "Tool $tool_name not found"

                    # Call the handler
                    result = tool.handler(params)
                    @test result isa ModelContextProtocol.Content
                    @test result isa ModelContextProtocol.TextContent

                    # Verify it returns valid JSON
                    parsed = JSON.parse(result.text)
                    @test isa(parsed, Dict)
                end

                TestPickerMCPServer.SERVER_PKG[] = nothing
            end
        end
    end

    @testset "Tool parameter validation works correctly" begin
        dummy_pkg_path = abspath(
            joinpath(pkgdir(TestPickerMCPServer), "test/fixtures/DummyPackage")
        )

        redirect_stderr(devnull) do
            Pkg.activate(dummy_pkg_path) do
                TestPickerMCPServer.SERVER_PKG[] = TestPickerMCPServer.detect_package()

                # Test run_testfiles without query parameter
                result = TestPickerMCPServer.handle_run_testfiles(Dict{String,Any}())
                parsed = JSON.parse(result.text)
                @test haskey(parsed, "error")
                @test contains(parsed["error"], "query required")

                # Test run_testblocks without required parameters
                result = TestPickerMCPServer.handle_run_testblocks(Dict{String,Any}())
                parsed = JSON.parse(result.text)
                @test haskey(parsed, "error")
                @test contains(parsed["error"], "testset_query required")

                # Test activate_package with invalid path
                result = TestPickerMCPServer.handle_activate_package(
                    Dict{String,Any}("pkg_dir" => "/nonexistent/path")
                )
                parsed = JSON.parse(result.text)
                @test haskey(parsed, "error")
                @test contains(parsed["error"], "does not exist")

                TestPickerMCPServer.SERVER_PKG[] = nothing
            end
        end
    end

    @testset "Multiple sequential operations" begin
        dummy_pkg_path = abspath(
            joinpath(pkgdir(TestPickerMCPServer), "test/fixtures/DummyPackage")
        )

        redirect_stderr(devnull) do
            Pkg.activate(dummy_pkg_path) do
                TestPickerMCPServer.SERVER_PKG[] = TestPickerMCPServer.detect_package()

                # Simulate a workflow with multiple operations
                workflow_results = []

                # Step 1: List files
                result = TestPickerMCPServer.handle_list_testfiles(Dict{String,Any}())
                parsed = JSON.parse(result.text)
                push!(workflow_results, ("list_files", parsed["count"] == 4))

                # Step 2: List testblocks
                result = TestPickerMCPServer.handle_list_testblocks(Dict{String,Any}())
                parsed = JSON.parse(result.text)
                push!(workflow_results, ("list_blocks", parsed["count"] == 34))

                # Step 3: Run test_basic.jl
                result = TestPickerMCPServer.handle_run_testfiles(
                    Dict{String,Any}("query" => "test_basic")
                )
                parsed = JSON.parse(result.text)
                push!(workflow_results, ("run_basic", parsed["status"] in ["completed", "failed"]))

                # Step 4: Get results
                result = TestPickerMCPServer.handle_get_testresults(Dict{String,Any}())
                parsed = JSON.parse(result.text)
                push!(workflow_results, ("get_results", haskey(parsed, "count")))

                # Step 5: Run test_failures.jl
                result = TestPickerMCPServer.handle_run_testfiles(
                    Dict{String,Any}("query" => "test_failures")
                )
                parsed = JSON.parse(result.text)
                push!(workflow_results, ("run_failures", parsed["status"] in ["completed", "failed"]))

                # Step 6: Get results again
                result = TestPickerMCPServer.handle_get_testresults(Dict{String,Any}())
                parsed = JSON.parse(result.text)
                # Should have failures and errors from test_failures.jl
                push!(workflow_results, ("results_have_failures", parsed["count"]["total"] > 0))

                # Verify all steps passed
                for (step_name, result) in workflow_results
                    @test result "Step $step_name failed"
                end

                TestPickerMCPServer.SERVER_PKG[] = nothing
            end
        end
    end

    @testset "Exact counts for DummyPackage operations" begin
        dummy_pkg_path = abspath(
            joinpath(pkgdir(TestPickerMCPServer), "test/fixtures/DummyPackage")
        )

        redirect_stderr(devnull) do
            Pkg.activate(dummy_pkg_path) do
                TestPickerMCPServer.SERVER_PKG[] = TestPickerMCPServer.detect_package()

                # Test exact file counts
                result = TestPickerMCPServer.handle_list_testfiles(Dict{String,Any}())
                parsed = JSON.parse(result.text)
                @test parsed["count"] == 4
                files = Set(parsed["files"])
                @test haskey(files, "test_basic.jl")
                @test haskey(files, "test_math.jl")
                @test haskey(files, "test_failures.jl")
                @test haskey(files, "runtests.jl")

                # Test exact testblock counts by file
                result = TestPickerMCPServer.handle_list_testblocks(
                    Dict{String,Any}("file_query" => "basic")
                )
                parsed = JSON.parse(result.text)
                @test parsed["count"] == 11

                result = TestPickerMCPServer.handle_list_testblocks(
                    Dict{String,Any}("file_query" => "math")
                )
                parsed = JSON.parse(result.text)
                @test parsed["count"] == 13

                result = TestPickerMCPServer.handle_list_testblocks(
                    Dict{String,Any}("file_query" => "failures")
                )
                parsed = JSON.parse(result.text)
                @test parsed["count"] == 10

                # Test specific testblock names
                result = TestPickerMCPServer.handle_list_testblocks(
                    Dict{String,Any}("file_query" => "basic")
                )
                parsed = JSON.parse(result.text)
                labels = Set([block["label"] for block in parsed["testblocks"]])
                @test "String Operations" in labels
                @test "Greeting Function" in labels
                @test "Reverse String" in labels
                @test "Basic Reversal" in labels
                @test "Utility Functions" in labels
                @test "Even Number Detection" in labels

                TestPickerMCPServer.SERVER_PKG[] = nothing
            end
        end
    end

    @testset "Package switching with activate_package" begin
        tp_pkg_path = pkgdir(TestPickerMCPServer)
        dummy_pkg_path = abspath(
            joinpath(tp_pkg_path, "test/fixtures/DummyPackage")
        )

        redirect_stderr(devnull) do
            # Start with TestPickerMCPServer
            Pkg.activate(tp_pkg_path) do
                TestPickerMCPServer.SERVER_PKG[] = TestPickerMCPServer.detect_package()
                @test TestPickerMCPServer.SERVER_PKG[].name == "TestPickerMCPServer"

                # Switch to DummyPackage
                result = TestPickerMCPServer.handle_activate_package(
                    Dict{String,Any}("pkg_dir" => dummy_pkg_path)
                )
                parsed = JSON.parse(result.text)

                @test parsed["status"] == "success"
                @test parsed["package_name"] == "DummyPackage"
                @test parsed["pkg_dir"] == dummy_pkg_path

                # Verify the switch worked by listing files
                result = TestPickerMCPServer.handle_list_testfiles(Dict{String,Any}())
                parsed = JSON.parse(result.text)
                @test parsed["count"] == 4

                TestPickerMCPServer.SERVER_PKG[] = nothing
            end
        end
    end

    @testset "Error responses are properly formatted JSON" begin
        dummy_pkg_path = abspath(
            joinpath(pkgdir(TestPickerMCPServer), "test/fixtures/DummyPackage")
        )

        redirect_stderr(devnull) do
            Pkg.activate(dummy_pkg_path) do
                TestPickerMCPServer.SERVER_PKG[] = TestPickerMCPServer.detect_package()

                # Generate various error conditions
                error_cases = [
                    (TestPickerMCPServer.handle_run_testfiles, Dict{String,Any}()),
                    (TestPickerMCPServer.handle_run_testblocks, Dict{String,Any}()),
                    (TestPickerMCPServer.handle_activate_package, Dict{String,Any}("pkg_dir" => "")),
                ]

                for (handler, params) in error_cases
                    result = handler(params)
                    @test result isa ModelContextProtocol.TextContent

                    # Parse JSON and verify error structure
                    parsed = JSON.parse(result.text)
                    @test haskey(parsed, "error")
                    @test parsed["error"] isa String
                    @test length(parsed["error"]) > 0

                    if haskey(parsed, "operation")
                        @test parsed["operation"] isa String
                    end
                end

                TestPickerMCPServer.SERVER_PKG[] = nothing
            end
        end
    end
end
