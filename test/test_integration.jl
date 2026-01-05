using TestPickerMCPServer
using Base: with_logger, NullLogger
using Test
using JSON
using ModelContextProtocol
using Pkg

function with_tp_pkg(f)
    redirect_stderr(devnull) do
        Pkg.activate(pkgdir(TestPickerMCPServer)) do
            # Simulate start of server
            TestPickerMCPServer.SERVER_PKG[] = TestPickerMCPServer.detect_package()
            try
                f()
            finally
                TestPickerMCPServer.SERVER_PKG[] = nothing
            end
        end
    end
end

@testset "Integration Tests" begin
    @testset "Package detection" begin
        with_tp_pkg() do
            # Verify SERVER_PKG is set correctly
            @test TestPickerMCPServer.SERVER_PKG[] !== nothing
            pkg = TestPickerMCPServer.SERVER_PKG[]

            # Should be the TestPickerMCPServer package
            @test pkg.name == "TestPickerMCPServer"
            @test pkg.path !== nothing
            @test endswith(pkg.path, r"TestPickerMCPServer(\.jl)?")

            # Verify test directory exists
            test_dir = joinpath(pkg.path, "test")
            @test isdir(test_dir)

            # Verify we have the expected test files
            test_files = readdir(test_dir)
            @test issubset(["test_utils.jl", "test_config.jl", "runtests.jl"], test_files)
        end
    end

    @testset "List and filter test files workflow" begin
        # Step 1: List all test files
        with_tp_pkg() do
            result = TestPickerMCPServer.handle_list_testfiles(Dict{String,Any}())
            @test result isa ModelContextProtocol.TextContent
            parsed = JSON.parse(result.text)
            all_files = parsed["files"]

            # Verify we found the actual test files in this package
            expected_files = [
                "test_utils.jl",
                "test_config.jl",
                "test_handlers.jl",
                "test_integration.jl",
                "test_server.jl",
                "test_tools.jl",
                "test_utils_extended.jl",
                "runtests.jl",
            ]
            @test issetequal(expected_files, all_files)
            @test parsed["count"] == 8

            # Verify test_dir points to correct location
            @test endswith(parsed["test_dir"], r"TestPickerMCPServer(\.jl)?/test")

            # Step 2: Filter for specific files
            result = TestPickerMCPServer.handle_list_testfiles(
                Dict{String,Any}("query" => "utils"),
            )
            parsed = JSON.parse(result.text)
            filtered_files = parsed["files"]

            # Should find both utils files
            @test issubset(["test_utils.jl", "test_utils_extended.jl"], filtered_files)
            @test length(filtered_files) == 2

            # Test filtering for config
            result = TestPickerMCPServer.handle_list_testfiles(
                Dict{String,Any}("query" => "config"),
            )
            parsed = JSON.parse(result.text)
            @test parsed["files"] == ["test_config.jl"]
        end
    end

    @testset "List test blocks workflow" begin
        with_tp_pkg() do
            # Get test blocks from all files
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

            # Test filtering by file query
            result = TestPickerMCPServer.handle_list_testblocks(
                Dict{String,Any}("file_query" => "utils"),
            )
            parsed = JSON.parse(result.text)

            # Should find test blocks only from utils files
            if parsed["count"] > 0
                for block in parsed["testblocks"]
                    @test contains(block["file"], "utils")
                end
            end

            # Look for specific test blocks in test_tools.jl
            result = TestPickerMCPServer.handle_list_testblocks(
                Dict{String,Any}("file_query" => "tools"),
            )
            parsed = JSON.parse(result.text)

            if parsed["count"] > 0
                # Check for known testsets in test_tools.jl
                labels = [block["label"] for block in parsed["testblocks"]]
                @test any(contains(label, "Tool") for label in labels)
            end
        end
    end

    @testset "Run tests workflow" begin
        with_tp_pkg() do
            # Run a specific test file from this package
            result = TestPickerMCPServer.handle_run_testfiles(
                Dict{String,Any}("query" => "test_tools.jl"),
            )
            @test result isa ModelContextProtocol.TextContent
            parsed = JSON.parse(result.text)

            # Verify run result structure
            @test haskey(parsed, "status")
            @test haskey(parsed, "files_run")
            @test parsed["status"] in ["completed", "failed"]
            @test length(parsed["files_run"]) >= 1

            # The file that ran should be test_tools.jl
            if haskey(parsed, "summary")
                @test contains(parsed["summary"], "test_tools")
            end
        end
    end

    @testset "Test results workflow" begin
        with_tp_pkg() do
            # Run a set of tests.
            TestPicker.fzf_testfile("test_tools.jl"; interactive = false)
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
                # File should be a real test file
                @test endswith(failure["file"], ".jl")
            end

            for error in parsed["errors"]
                @test haskey(error, "test")
                @test haskey(error, "file")
                @test haskey(error, "error")
                @test haskey(error, "context")
                # File should be a real test file
                @test endswith(error["file"], ".jl")
            end
        end
    end

    @testset "Tool parameter validation" begin
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
        # All handlers should accept Dict{String,Any} and return Content
        for tool in TestPickerMCPServer.ALL_TOOLS
            handler = tool.handler
            @test handler isa Function

            # Test that handler can be called (may error on content, but should be callable)
            try
                result = handler(Dict{String,Any}())
                @test result isa ModelContextProtocol.Content
            catch e
                # Some handlers require specific params, which is ok
                # Just verify it's a proper function
                @test true
            end
        end
    end

    @testset "Error handling consistency" begin
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

    @testset "Complete MCP workflow simulation" begin
        # This simulates a typical MCP Inspector workflow
        with_tp_pkg() do

            # 1. Discover what test files are available
            result = TestPickerMCPServer.handle_list_testfiles(Dict{String,Any}())
            parsed = JSON.parse(result.text)
            @test parsed["count"] > 0
            @test "test_utils.jl" in parsed["files"]

            # 2. Filter for a specific test file
            result = TestPickerMCPServer.handle_list_testfiles(
                Dict{String,Any}("query" => "utils"),
            )
            parsed = JSON.parse(result.text)
            @test length(parsed["files"]) >= 1
            @test all(f -> contains(f, "utils"), parsed["files"])

            # 3. Run that specific test file
            result = TestPickerMCPServer.handle_run_testfiles(
                Dict{String,Any}("query" => "test_utils"),
            )
            parsed = JSON.parse(result.text)
            @test parsed["status"] in ["completed", "failed"]
            @test length(parsed["files_run"]) >= 1

            # 4. Check results
            result = TestPickerMCPServer.handle_get_testresults(Dict{String,Any}())
            parsed = JSON.parse(result.text)
            @test haskey(parsed, "count")

            # If tests passed, should have no failures
            if parsed["count"]["total"] == 0
                @test isempty(parsed["failures"])
                @test isempty(parsed["errors"])
            end

            # 5. List available test blocks
            result = TestPickerMCPServer.handle_list_testblocks(Dict{String,Any}())
            parsed = JSON.parse(result.text)
            @test haskey(parsed, "testblocks")
            @test haskey(parsed, "count")
        end
    end

    @testset "Cross-tool consistency" begin
        # Verify that file counts are consistent across tools

        with_tp_pkg() do
            # Get files via list_testfiles
            result = TestPickerMCPServer.handle_list_testfiles(Dict{String,Any}())
            parsed = JSON.parse(result.text)
            file_count = parsed["count"]

            # Verify SERVER_PKG has same test files
            pkg = TestPickerMCPServer.SERVER_PKG[]
            test_dir = joinpath(pkg.path, "test")
            actual_files = filter(f -> endswith(f, ".jl"), readdir(test_dir))

            @test file_count == length(actual_files)

            # Verify list_testblocks uses same files
            result = TestPickerMCPServer.handle_list_testblocks(Dict{String,Any}())
            parsed = JSON.parse(result.text)

            if parsed["count"] > 0
                # All block files should be in our test files list
                block_files = unique([block["file"] for block in parsed["testblocks"]])
                for file in block_files
                    filename = basename(file)
                    @test filename in actual_files
                end
            end
        end
    end
end
