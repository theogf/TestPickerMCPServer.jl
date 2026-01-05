using TestPickerMCPServer
using Test
using JSON
using ModelContextProtocol

@testset "Handler Functions" begin
    @testset "handle_list_testfiles" begin
        # Test with empty query
        result = TestPickerMCPServer.handle_list_testfiles(Dict{String,Any}())
        @test result isa ModelContextProtocol.TextContent
        parsed = JSON.parse(result.text)
        @test haskey(parsed, "test_dir")
        @test haskey(parsed, "files")
        @test haskey(parsed, "count")
        @test parsed["count"] >= 0

        # Test with query parameter
        result =
            TestPickerMCPServer.handle_list_testfiles(Dict{String,Any}("query" => "test"))
        @test result isa ModelContextProtocol.TextContent
        parsed = JSON.parse(result.text)
        @test haskey(parsed, "files")
    end

    @testset "handle_list_test_blocks" begin
        # Test with empty file query
        result = TestPickerMCPServer.handle_list_test_blocks(Dict{String,Any}())
        @test result isa ModelContextProtocol.TextContent
        parsed = JSON.parse(result.text)
        @test haskey(parsed, "test_blocks")
        @test haskey(parsed, "count")
        @test parsed["count"] >= 0

        # Test with file query
        result = TestPickerMCPServer.handle_list_test_blocks(
            Dict{String,Any}("file_query" => "utils"),
        )
        @test result isa ModelContextProtocol.TextContent
    end

    @testset "handle_get_testresults" begin
        result = TestPickerMCPServer.handle_get_testresults(Dict{String,Any}())
        @test result isa ModelContextProtocol.TextContent
        parsed = JSON.parse(result.text)
        @test haskey(parsed, "failures")
        @test haskey(parsed, "errors")
        @test haskey(parsed, "count")
        @test parsed["failures"] isa Vector
        @test parsed["errors"] isa Vector
    end

    @testset "handle_run_testfiles - missing query" begin
        result = TestPickerMCPServer.handle_run_testfiles(Dict{String,Any}())
        @test result isa ModelContextProtocol.TextContent
        @test occursin("Error", result.text)
    end

    @testset "handle_run_testblocks - missing query" begin
        result = TestPickerMCPServer.handle_run_testblocks(Dict{String,Any}())
        @test result isa ModelContextProtocol.TextContent
        @test occursin("Error", result.text)
    end

    @testset "handle_activate_package - missing dir" begin
        original_active = Base.active_project()
        result = try
            with_logger(NullLogger()) do
                TestPickerMCPServer.handle_activate_package(Dict{String,Any}())
            end
        finally
            Pkg.activate(original_active; io = devnull)
        end
        @test result isa ModelContextProtocol.TextContent
        @test occursin("Error", result.text)
    end

    @testset "handle_activate_package - invalid dir" begin
        original_active = Base.active_project()
        result = try
            with_logger(NullLogger()) do
                TestPickerMCPServer.handle_activate_package(
                    Dict{String,Any}("pkg_dir" => "/nonexistent/path"),
                )
            end
        finally
            Pkg.activate(original_active; io = devnull)
        end
        @test result isa ModelContextProtocol.TextContent
        # Should return error in JSON or text
    end
end
