using TestPickerMCPServer
using Test
using JSON
using Pkg
using ModelContextProtocol

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
end
