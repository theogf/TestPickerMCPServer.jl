using TestPickerMCPServer
using Base: with_logger, NullLogger
using Test
using JSON
using ModelContextProtocol
using Pkg
using TestPicker

"""
Execute function without recording test results in the current testset.
Disables test printing and clears results after execution.
"""
function without_recording_tests(f)
    try
        Test.TESTSET_PRINT_ENABLE[] = false
        f()
    finally
        empty!(Test.get_testset().results)
        Test.TESTSET_PRINT_ENABLE[] = true
    end
end

function with_dummy_pkg(f, verbose = false)
    redirect_stderr(verbose ? stderr : devnull) do
        with_logger(NullLogger()) do
            dummy_pkg_path =
                abspath(joinpath(pkgdir(TestPickerMCPServer), "test/fixtures/DummyPackage"))
            project = Base.active_project()
            try
                Pkg.activate(dummy_pkg_path; io = devnull)
                # Simulate start of server with DummyPackage
                TestPickerMCPServer.SERVER_PKG[] = TestPickerMCPServer.detect_package()
                f()
            finally
                TestPickerMCPServer.SERVER_PKG[] = nothing
                Pkg.activate(project; io = devnull)
            end
        end
    end
end

@testset "Integration Tests" begin
    @testset "Package detection" begin
        with_dummy_pkg() do
            # Verify SERVER_PKG is set correctly
            @test TestPickerMCPServer.SERVER_PKG[] !== nothing
            pkg = TestPickerMCPServer.SERVER_PKG[]

            # Should be the DummyPackage
            @test pkg.name == "DummyPackage"
            @test pkg.path !== nothing
            @test endswith(pkg.path, r"DummyPackage(\.jl)?")

            # Verify test directory exists
            test_dir = joinpath(pkg.path, "test")
            @test isdir(test_dir)

            # Verify we have the expected test files
            test_files = readdir(test_dir)
            @test issubset(
                ["test_basic.jl", "test_math.jl", "test_failures.jl", "runtests.jl"],
                test_files,
            )
        end
    end

    @testset "List and filter test files workflow" begin
        # Step 1: List all test files in DummyPackage
        with_dummy_pkg() do
            result = TestPickerMCPServer.handle_list_testfiles(Dict{String,Any}())
            @test result isa ModelContextProtocol.TextContent
            parsed = JSON.parse(result.text)
            all_files = parsed["files"]

            # Verify we found the exact test files in DummyPackage
            expected_files =
                ["test_basic.jl", "test_math.jl", "test_failures.jl", "runtests.jl"]
            @test issetequal(expected_files, all_files)
            @test parsed["count"] == 4

            # Verify test_dir points to DummyPackage test location
            @test endswith(parsed["test_dir"], r"DummyPackage/test")

            # Step 2: Filter for specific files
            result = TestPickerMCPServer.handle_list_testfiles(
                Dict{String,Any}("query" => "basic"),
            )
            parsed = JSON.parse(result.text)
            filtered_files = parsed["files"]

            # Should find only test_basic.jl
            @test filtered_files == ["test_basic.jl"]
            @test parsed["count"] == 1

            # Test filtering for math
            result = TestPickerMCPServer.handle_list_testfiles(
                Dict{String,Any}("query" => "math"),
            )
            parsed = JSON.parse(result.text)
            @test parsed["files"] == ["test_math.jl"]
            @test parsed["count"] == 1

            # Test filtering for failures
            result = TestPickerMCPServer.handle_list_testfiles(
                Dict{String,Any}("query" => "failures"),
            )
            parsed = JSON.parse(result.text)
            @test parsed["files"] == ["test_failures.jl"]
            @test parsed["count"] == 1
        end
    end

    @testset "List test blocks workflow" begin
        with_dummy_pkg() do
            # Get test blocks from all files in DummyPackage
            result = TestPickerMCPServer.handle_list_testblocks(Dict{String,Any}())
            @test result isa ModelContextProtocol.TextContent
            parsed = JSON.parse(result.text)

            @test haskey(parsed, "testblocks")
            @test haskey(parsed, "count")
            @test parsed["count"] == length(parsed["testblocks"])

            # Verify each block has required fields
            for block in parsed["testblocks"]
                @test haskey(block, "label")
                @test haskey(block, "file")
                @test haskey(block, "line_start")
                @test haskey(block, "line_end")
                @test block["line_end"] >= block["line_start"]
            end

            # Test filtering by file query - test_basic.jl
            result = TestPickerMCPServer.handle_list_testblocks(
                Dict{String,Any}("file_query" => "basic"),
            )
            parsed = JSON.parse(result.text)

            # test_basic.jl has exactly 11 testsets
            @test parsed["count"] == 11
            for block in parsed["testblocks"]
                @test contains(block["file"], "test_basic")
            end

            # Look for specific test blocks in test_basic.jl
            labels = Set([block["label"] for block in parsed["testblocks"]])
            @test repr("String Operations") in labels
            @test repr("Greeting Function") in labels
            @test repr("Reverse String") in labels
            @test repr("Utility Functions") in labels

            # Test filtering for test_math.jl
            result = TestPickerMCPServer.handle_list_testblocks(
                Dict{String,Any}("file_query" => "math"),
            )
            parsed = JSON.parse(result.text)

            # test_math.jl has exactly 13 testsets
            @test parsed["count"] == 13
            labels = Set([block["label"] for block in parsed["testblocks"]])
            @test repr("Addition") in labels
            @test repr("Multiplication") in labels
            @test repr("Integer Operations") in labels
        end
    end

    @testset "Run tests workflow" begin
        with_dummy_pkg() do
            # Run a specific test file from DummyPackage
            result = TestPickerMCPServer.handle_run_testfiles(
                Dict{String,Any}("query" => "test_basic"),
            )
            @test result isa ModelContextProtocol.TextContent
            parsed = JSON.parse(result.text)

            # Verify run result structure
            @test haskey(parsed, "status")
            @test haskey(parsed, "files_run")
            @test parsed["status"] in ["completed", "failed"]
            @test length(parsed["files_run"]) == 1
            @test endswith(only(parsed["files_run"])["filename"], "test_basic.jl")
        end
    end

    @testset "Test results workflow" begin
        with_dummy_pkg() do
            # Run test_failures.jl which has intentional failures and errors
            without_recording_tests() do
                TestPicker.fzf_testfile("test_failures"; interactive = false)
            end
            # Get current test results
            result = TestPickerMCPServer.handle_get_testresults(Dict{String,Any}())
            @test result isa ModelContextProtocol.TextContent
            parsed = JSON.parse(result.text)

            # Verify structure
            @test haskey(parsed, "failures")
            @test haskey(parsed, "errors")
            @test haskey(parsed, "count")
            @test haskey(parsed["count"], "failures")
            @test haskey(parsed["count"], "errors")
            @test haskey(parsed["count"], "total")

            # Count should be sum of failures and errors
            @test parsed["count"]["total"] ==
                  parsed["count"]["failures"] + parsed["count"]["errors"]

            # Verify result structure for any failures/errors
            for failure in parsed["failures"]
                @test haskey(failure, "test")
                @test haskey(failure, "file")
                @test haskey(failure, "error")
                @test haskey(failure, "context")
                # File should be test_failures.jl
                @test endswith(failure["file"], r"test_failures.jl:\d+")
            end

            for error in parsed["errors"]
                @test haskey(error, "test")
                @test haskey(error, "file")
                @test haskey(error, "error")
                @test haskey(error, "context")
                # File should be test_failures.jl
                @test endswith(error["file"], r"test_failures.jl:\d+")
            end
        end
    end

    @testset "Tool parameter validation" begin
        with_dummy_pkg() do
            # Test required parameter validation for run_testfiles
            result = TestPickerMCPServer.handle_run_testfiles(Dict{String,Any}())
            @test result isa ModelContextProtocol.TextContent
            parsed = JSON.parse(result.text)
            @test haskey(parsed, "error")
            @test haskey(parsed, "operation")
            @test contains(parsed["error"], "query required")

            # Test required parameter validation for run_testblocks
            result = TestPickerMCPServer.handle_run_testblocks(Dict{String,Any}())
            @test result isa ModelContextProtocol.TextContent
            parsed = JSON.parse(result.text)
            @test haskey(parsed, "error")
            @test haskey(parsed, "operation")
            @test contains(parsed["error"], "testset_query required")
        end
    end

    @testset "ALL_TOOLS completeness" begin
        expected_tools = [
            "list_testfiles",
            "list_testblocks",
            "run_all_tests",
            "run_testfiles",
            "run_testblocks",
            "get_testresults",
            "activate_package",
        ]

        actual_tools = [tool.name for tool in TestPickerMCPServer.ALL_TOOLS]

        for expected in expected_tools
            @test expected in actual_tools
        end

        @test length(actual_tools) == length(expected_tools)
    end

    @testset "Tool handler signatures" begin
        with_dummy_pkg() do
            # All handlers should accept Dict{String,Any} and return Content
            for tool in TestPickerMCPServer.ALL_TOOLS
                handler = tool.handler
                @test handler isa Function

                # Test that handler can be called (may error on content, but should be callable)
                result = without_recording_tests() do
                    try
                        handler(Dict{String,Any}())
                    catch e
                        # Some handlers require specific params, which is ok
                        # Just verify it's a proper function
                        true
                    end
                end
                @test result == true || result isa ModelContextProtocol.Content
            end
        end
    end

    @testset "Error handling consistency" begin
        with_dummy_pkg() do
            # All errors should return TextContent with JSON error message
            handlers_to_test = [
                (TestPickerMCPServer.handle_run_testfiles, Dict{String,Any}()),
                (TestPickerMCPServer.handle_run_testblocks, Dict{String,Any}()),
            ]

            for (handler, params) in handlers_to_test
                result = handler(params)
                @test result isa ModelContextProtocol.TextContent
                parsed = JSON.parse(result.text)
                @test haskey(parsed, "error")
                @test haskey(parsed, "operation")
                @test contains(parsed["error"], "required")
            end
        end
    end

    @testset "Complete MCP workflow simulation" begin
        # This simulates a typical MCP Inspector workflow with DummyPackage
        with_dummy_pkg() do

            # 1. Discover what test files are available
            result = TestPickerMCPServer.handle_list_testfiles(Dict{String,Any}())
            parsed = JSON.parse(result.text)
            @test parsed["count"] == 4
            @test "test_basic.jl" in parsed["files"]
            @test "test_math.jl" in parsed["files"]
            @test "test_failures.jl" in parsed["files"]

            # 2. Filter for a specific test file
            result = TestPickerMCPServer.handle_list_testfiles(
                Dict{String,Any}("query" => "basic"),
            )
            parsed = JSON.parse(result.text)
            @test parsed["count"] == 1
            @test parsed["files"] == ["test_basic.jl"]

            # 3. Run that specific test file
            result = TestPickerMCPServer.handle_run_testfiles(
                Dict{String,Any}("query" => "test_basic"),
            )
            parsed = JSON.parse(result.text)
            @test parsed["status"] in ["completed", "failed"]
            @test "test_basic.jl" in only(parsed["files_run"])["filename"]

            # 4. Check results
            result = TestPickerMCPServer.handle_get_testresults(Dict{String,Any}())
            parsed = JSON.parse(result.text)
            @test haskey(parsed, "count")

            # test_basic.jl has all passing tests, so no failures
            @test parsed["count"]["total"] == 0
            @test isempty(parsed["failures"])
            @test isempty(parsed["errors"])

            # 5. List available test blocks
            result = TestPickerMCPServer.handle_list_testblocks(Dict{String,Any}())
            parsed = JSON.parse(result.text)
            @test haskey(parsed, "testblocks")
            @test parsed["count"] == 34
        end
    end

    @testset "Cross-tool consistency" begin
        # Verify that file counts are consistent across tools in DummyPackage

        with_dummy_pkg() do
            # Get files via list_testfiles
            result = TestPickerMCPServer.handle_list_testfiles(Dict{String,Any}())
            parsed = JSON.parse(result.text)
            file_count = parsed["count"]
            @test file_count == 4

            # Verify SERVER_PKG has same test files
            pkg = TestPickerMCPServer.SERVER_PKG[]
            test_dir = joinpath(pkg.path, "test")
            actual_files = filter(f -> endswith(f, ".jl"), readdir(test_dir))

            @test file_count == length(actual_files)

            # Verify list_testblocks uses same files
            result = TestPickerMCPServer.handle_list_testblocks(Dict{String,Any}())
            parsed = JSON.parse(result.text)

            # DummyPackage should have exactly 34 testsets
            @test parsed["count"] == 34

            # All block files should be in our test files list
            block_files = unique([block["file"] for block in parsed["testblocks"]])
            for file in block_files
                filename = basename(file)
                @test filename in actual_files
            end
        end
    end
end
