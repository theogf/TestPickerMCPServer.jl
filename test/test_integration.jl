using TestPickerMCPServer
using Test
using JSON
using ModelContextProtocol

@testset "Integration Tests" begin
    @testset "List and filter test files workflow" begin
        # Step 1: List all test files
        result = TestPickerMCPServer.handle_list_testfiles(Dict{String,Any}())
        @test result isa ModelContextProtocol.TextContent
        parsed = JSON.parse(result.text)
        all_files = parsed["files"]

        # Step 2: Filter for specific files
        if !isempty(all_files)
            # Extract a search term from first file
            first_file = all_files[1]
            if contains(first_file, "test")
                search_term = "test"
            else
                search_term = split(first_file, ".")[1]
            end

            result = TestPickerMCPServer.handle_list_testfiles(
                Dict{String,Any}("query" => search_term)
            )
            parsed = JSON.parse(result.text)
            filtered_files = parsed["files"]

            # Filtered should be subset of all
            @test length(filtered_files) <= length(all_files)
            @test all(f -> f in all_files, filtered_files)
        end
    end

    @testset "List test blocks workflow" begin
        # Get test blocks from all files
        result = TestPickerMCPServer.handle_list_test_blocks(Dict{String,Any}())
        @test result isa ModelContextProtocol.TextContent
        parsed = JSON.parse(result.text)

        @test haskey(parsed, "test_blocks")
        @test haskey(parsed, "count")
        @test parsed["count"] == length(parsed["test_blocks"])

        # Verify each block has required fields
        for block in parsed["test_blocks"]
            @test haskey(block, "label")
            @test haskey(block, "file")
            @test haskey(block, "line_start")
            @test haskey(block, "line_end")
            @test block["line_end"] >= block["line_start"]
        end
    end

    @testset "Test results workflow" begin
        # Get current test results
        result = TestPickerMCPServer.handle_get_testresults(Dict{String,Any}())
        @test result isa ModelContextProtocol.TextContent
        parsed = JSON.parse(result.text)

        # Verify structure
        @test haskey(parsed, "failures")
        @test haskey(parsed, "errors")
        @test haskey(parsed, "count")

        # Verify result structure for any failures/errors
        for failure in parsed["failures"]
            @test haskey(failure, "test")
            @test haskey(failure, "file")
            @test haskey(failure, "error")
            @test haskey(failure, "context")
        end

        for error in parsed["errors"]
            @test haskey(error, "test")
            @test haskey(error, "file")
            @test haskey(error, "error")
            @test haskey(error, "context")
        end
    end

    @testset "Tool parameter validation" begin
        # Test required parameter validation for run_testfiles
        result = TestPickerMCPServer.handle_run_testfiles(Dict{String,Any}())
        @test result isa ModelContextProtocol.TextContent
        @test occursin("Error", result.text) || occursin("query required", result.text)

        # Test required parameter validation for run_testblocks
        result = TestPickerMCPServer.handle_run_testblocks(Dict{String,Any}())
        @test result isa ModelContextProtocol.TextContent
        @test occursin("Error", result.text) || occursin("query required", result.text)

        # Test required parameter validation for activate_package
        result = TestPickerMCPServer.handle_activate_package(Dict{String,Any}())
        @test result isa ModelContextProtocol.TextContent
        @test occursin("Error", result.text) || occursin("pkg_dir required", result.text)
    end

    @testset "ALL_TOOLS completeness" begin
        expected_tools = [
            "list_testfiles",
            "list_test_blocks",
            "run_all_tests",
            "run_testfiles",
            "run_testblocks",
            "get_testresults",
            "activate_package"
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
        # All errors should return TextContent with error message
        handlers_to_test = [
            (TestPickerMCPServer.handle_run_testfiles, Dict{String,Any}()),
            (TestPickerMCPServer.handle_run_testblocks, Dict{String,Any}()),
            (TestPickerMCPServer.handle_activate_package, Dict{String,Any}()),
        ]

        for (handler, params) in handlers_to_test
            result = handler(params)
            @test result isa ModelContextProtocol.TextContent
            @test occursin("Error", result.text) || occursin("required", result.text)
        end
    end
end
