using TestPickerMCPServer
using Test
using JSON
using ModelContextProtocol
using Pkg

@testset "Extended Utility Functions" begin
    @testset "with_error_handling - success case" begin
        result = TestPickerMCPServer.with_error_handling("test_op") do
            TestPickerMCPServer.to_json(Dict("success" => true))
        end
        @test result isa ModelContextProtocol.TextContent
        parsed = JSON.parse(result.text)
        @test parsed["success"] == true
    end

    @testset "with_error_handling - error case" begin
        result = TestPickerMCPServer.with_error_handling("test_op") do
            error("Test error")
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
        try
            pkg = TestPickerMCPServer.detect_package()
            @test pkg isa Pkg.Types.PackageSpec
            @test !isnothing(pkg.name)
        catch e
            if e isa TestPicker.TestEnvError && contains(e.msg, "unnamed project")
                @warn "Skipping detect_package test: running in unnamed test environment (CI)"
                @test_skip true
            else
                rethrow()
            end
        end
    end

    @testset "activate_package" begin
        # Test with current directory (should succeed)
        original_active = Base.active_project()
        TestPickerMCPServer.activate_package(pwd())
        @test true  # If we get here, no error was thrown

        # Note: Can't easily test invalid paths without side effects
    end

    @testset "parse_results_file - structure validation" begin
        pkg = Pkg.Types.PackageSpec(name="Test", path=pwd())
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
end
