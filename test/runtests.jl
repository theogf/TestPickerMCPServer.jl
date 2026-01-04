using TestPickerMCPServer
using Test
using JSON

@testset "TestPickerMCPServer.jl" begin
    @testset "Utility Functions" begin
        @testset "filter_files" begin
            files = ["test_feature.jl", "test_utils.jl", "runtests.jl"]

            # Empty query returns all
            @test TestPickerMCPServer.filter_files(files, "") == files

            # Case-insensitive substring match
            @test TestPickerMCPServer.filter_files(files, "feature") == ["test_feature.jl"]
            @test TestPickerMCPServer.filter_files(files, "test") == ["test_feature.jl", "test_utils.jl"]
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
            using Pkg
            pkg = Pkg.Types.PackageSpec(name="Fake", path="/nonexistent")
            result = TestPickerMCPServer.parse_results_file(pkg)

            @test result["count"]["total"] == 0
            @test isempty(result["failures"])
            @test isempty(result["errors"])
        end
    end

    @testset "Tool Definitions" begin
        @test length(TestPickerMCPServer.ALL_TOOLS) == 6

        tool_names = [tool.name for tool in TestPickerMCPServer.ALL_TOOLS]
        @test "list_test_files" in tool_names
        @test "list_test_blocks" in tool_names
        @test "run_all_tests" in tool_names
        @test "run_test_files" in tool_names
        @test "run_test_blocks" in tool_names
        @test "get_test_results" in tool_names
    end

    @testset "Module Exports" begin
        @test isdefined(TestPickerMCPServer, :start_server)
    end
end
