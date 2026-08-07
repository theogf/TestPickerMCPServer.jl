using TestPickerMCPServer
using Test
using JSON
using Pkg
using ModelContextProtocol
using Base: with_logger, NullLogger

@testset "Utility Functions" begin
    @testset "filter_files" begin
        files = ["test_feature.jl", "test_utils.jl", "runtests.jl"]

        # Empty query returns all
        @test TestPickerMCPServer.filter_files(files, "") == files

        # Case-insensitive substring match
        @test TestPickerMCPServer.filter_files(files, "feature") == ["test_feature.jl"]
        @test TestPickerMCPServer.filter_files(files, "test") == ["test_feature.jl", "test_utils.jl", "runtests.jl"]
        @test TestPickerMCPServer.filter_files(files, "utils") == ["test_utils.jl"]
    end

    @testset "to_json" begin
        data = Dict("key" => "value", "count" => 42)
        result = TestPickerMCPServer.to_json(data)

        @test result isa ModelContextProtocol.TextContent
        parsed = JSON.parse(result.text)
        @test parsed["key"] == "value"
        @test parsed["count"] == 42
    end

    @testset "parse_results_file - non-existent" begin
        pkg = Pkg.Types.PackageSpec(name="Fake", path="/nonexistent")
        result = TestPickerMCPServer.parse_results_file(pkg)

        @test result["count"]["total"] == 0
        @test isempty(result["failures"])
        @test isempty(result["errors"])
    end

    @testset "with_error_handling - success case" begin
        result = TestPickerMCPServer.with_error_handling("test_op") do
            TestPickerMCPServer.to_json(Dict("success" => true))
        end
        @test result isa ModelContextProtocol.TextContent
        parsed = JSON.parse(result.text)
        @test parsed["success"] == true
    end

    @testset "with_error_handling - error case" begin
        result = with_logger(NullLogger()) do
            TestPickerMCPServer.with_error_handling("test_op") do
                error("Test error")
            end
        end
        @test result isa ModelContextProtocol.TextContent
        @test occursin("Error", result.text)
        @test occursin("test_op", result.text)
    end

    @testset "filter_files - edge cases" begin
        # Empty list
        @test TestPickerMCPServer.filter_files(String[], "query") == String[]

        # Case insensitivity
        files = ["TestFile.jl", "testfile.jl", "TESTFILE.jl"]
        result = TestPickerMCPServer.filter_files(files, "test")
        @test length(result) == 3

        # Partial match
        files = ["prefix_test_suffix.jl", "test.jl", "notest.jl"]
        result = TestPickerMCPServer.filter_files(files, "test")
        @test length(result) == 3

        # No matches
        files = ["file1.jl", "file2.jl"]
        result = TestPickerMCPServer.filter_files(files, "nonexistent")
        @test isempty(result)
    end

    @testset "to_json - various data types" begin
        # Nested dict
        data = Dict("nested" => Dict("key" => "value"), "array" => [1, 2, 3])
        result = TestPickerMCPServer.to_json(data)
        parsed = JSON.parse(result.text)
        @test parsed["nested"]["key"] == "value"
        @test parsed["array"] == [1, 2, 3]

        # Empty dict
        result = TestPickerMCPServer.to_json(Dict{String,Any}())
        @test result isa ModelContextProtocol.TextContent
        parsed = JSON.parse(result.text)
        @test isempty(parsed)

        # With numbers and booleans
        data = Dict("int" => 42, "float" => 3.14, "bool" => true, "null" => nothing)
        result = TestPickerMCPServer.to_json(data)
        parsed = JSON.parse(result.text)
        @test parsed["int"] == 42
        @test parsed["float"] ≈ 3.14
        @test parsed["bool"] == true
        @test parsed["null"] === nothing
    end

    @testset "detect_package" begin
        # Should detect current package (TestPickerMCPServer itself when running tests)
        # Note: This may fail in CI environments with unnamed test projects
        Pkg.activate(pkgdir(TestPickerMCPServer)) do
            pkg = TestPickerMCPServer.detect_package()
            @test pkg isa Pkg.Types.PackageSpec
            @test !isnothing(pkg.name)
        end

        # Should return nothing when no valid package is found
        tmp_dir = mktempdir()
        original_project = Base.active_project()
        try
            redirect_stderr(devnull) do
                Pkg.activate(tmp_dir)
                with_logger(NullLogger()) do
                    pkg = TestPickerMCPServer.detect_package()
                    @test isnothing(pkg)
                end
            end
        finally
            Pkg.activate(original_project; io=devnull)
            rm(tmp_dir; recursive=true)
        end
    end

    @testset "parse_results_file - structure validation" begin
        pkg = Pkg.Types.PackageSpec(name = "Test", path = pwd())
        result = TestPickerMCPServer.parse_results_file(pkg)

        # Verify structure
        @test haskey(result, "failures")
        @test haskey(result, "errors")
        @test haskey(result, "count")
        @test haskey(result["count"], "failures")
        @test haskey(result["count"], "errors")
        @test haskey(result["count"], "total")

        # Verify types
        @test result["failures"] isa Vector
        @test result["errors"] isa Vector
        @test result["count"]["failures"] isa Int
        @test result["count"]["errors"] isa Int
        @test result["count"]["total"] isa Int

        # Verify consistency
        @test result["count"]["total"] ==
              result["count"]["failures"] + result["count"]["errors"]
        @test result["count"]["failures"] == length(result["failures"])
        @test result["count"]["errors"] == length(result["errors"])
    end

    @testset "format_file_results - status reporting" begin
        using TestPicker

        # Mock EvalResult objects for testing
        # EvalResult constructor: EvalResult(success::Bool, info::TestInfo, result::T)
        success_info = TestPicker.TestInfo("test_pass.jl", "", 1)
        failure_info = TestPicker.TestInfo("test_fail.jl", "", 1)

        success_result = TestPicker.EvalResult(true, success_info, nothing)
        failure_exc = Test.TestSetException(3, 2, 0, 0, [])
        failure_result = TestPicker.EvalResult(false, failure_info, failure_exc)

        # Test with all passing results
        results_passing = [success_result]
        formatted = TestPickerMCPServer.format_file_results(results_passing)
        @test formatted["status"] == "completed"
        @test formatted["outcome"] == "passed"
        @test formatted["count"] == 1
        @test formatted["files_run"][1]["success"] == true

        # Test with failing results (TestSetException - has counts)
        results_failing = [failure_result]
        formatted = TestPickerMCPServer.format_file_results(results_failing)
        @test formatted["status"] == "completed"
        @test formatted["outcome"] == "failed"
        @test formatted["count"] == 1
        @test formatted["files_run"][1]["success"] == false
        @test formatted["files_run"][1]["pass"] == 3
        @test formatted["files_run"][1]["fail"] == 2
        @test formatted["files_run"][1]["error"] == 0

        # Test with error results (non-TestSetException, e.g. UndefVarError - no counts)
        error_info = TestPicker.TestInfo("test_error.jl", "", 1)
        error_result = TestPicker.EvalResult(false, error_info, UndefVarError(:nonexistent_function))
        results_error = [error_result]
        formatted = TestPickerMCPServer.format_file_results(results_error)
        @test formatted["status"] == "completed"
        @test formatted["outcome"] == "failed"
        @test formatted["count"] == 1
        @test formatted["files_run"][1]["success"] == false
        @test !haskey(formatted["files_run"][1], "pass")
        @test !haskey(formatted["files_run"][1], "fail")
        @test !haskey(formatted["files_run"][1], "error")

        # Test with mixed results (at least one failure)
        results_mixed = [success_result, failure_result]
        formatted = TestPickerMCPServer.format_file_results(results_mixed)
        @test formatted["status"] == "completed"
        @test formatted["outcome"] == "failed"
        @test formatted["count"] == 2

        # Test with nothing
        formatted = TestPickerMCPServer.format_file_results(nothing)
        @test formatted["status"] == "completed"
        @test formatted["outcome"] == "no_tests"
        @test formatted["count"] == 0
    end

    @testset "format_block_results - status reporting" begin
        using TestPicker

        # Mock EvalResult objects for test blocks
        # EvalResult constructor: EvalResult(success::Bool, info::TestInfo, result::T)
        success_info = TestPicker.TestInfo("test.jl", "Passing Test", 1)
        failure_info = TestPicker.TestInfo("test.jl", "Failing Test", 10)

        success_result = TestPicker.EvalResult(true, success_info, nothing)
        failure_exc = Test.TestSetException(5, 1, 0, 0, [])
        failure_result = TestPicker.EvalResult(false, failure_info, failure_exc)

        # Test with all passing results
        results_passing = [success_result]
        formatted = TestPickerMCPServer.format_block_results(results_passing)
        @test formatted["status"] == "completed"
        @test formatted["outcome"] == "passed"
        @test formatted["count"] == 1
        @test formatted["blocks_run"][1]["success"] == true

        # Test with failing results (TestSetException - has counts)
        results_failing = [failure_result]
        formatted = TestPickerMCPServer.format_block_results(results_failing)
        @test formatted["status"] == "completed"
        @test formatted["outcome"] == "failed"
        @test formatted["count"] == 1
        @test formatted["blocks_run"][1]["success"] == false
        @test formatted["blocks_run"][1]["pass"] == 5
        @test formatted["blocks_run"][1]["fail"] == 1
        @test formatted["blocks_run"][1]["error"] == 0

        # Test with error results (non-TestSetException, e.g. MethodError - no counts)
        error_info = TestPicker.TestInfo("test.jl", "Error Block", 20)
        error_result = TestPicker.EvalResult(false, error_info, MethodError(+, ("a", "b")))
        results_error = [error_result]
        formatted = TestPickerMCPServer.format_block_results(results_error)
        @test formatted["status"] == "completed"
        @test formatted["outcome"] == "failed"
        @test formatted["count"] == 1
        @test formatted["blocks_run"][1]["success"] == false
        @test !haskey(formatted["blocks_run"][1], "pass")
        @test !haskey(formatted["blocks_run"][1], "fail")
        @test !haskey(formatted["blocks_run"][1], "error")

        # Test with mixed results (at least one failure)
        results_mixed = [success_result, failure_result]
        formatted = TestPickerMCPServer.format_block_results(results_mixed)
        @test formatted["status"] == "completed"
        @test formatted["outcome"] == "failed"
        @test formatted["count"] == 2

        # Test with nothing
        formatted = TestPickerMCPServer.format_block_results(nothing)
        @test formatted["status"] == "completed"
        @test formatted["outcome"] == "no_tests"
        @test formatted["count"] == 0
    end
end
