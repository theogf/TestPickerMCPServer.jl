using TestPickerMCPServer
using Test

@testset "Tool Definitions" begin
    @testset "All tools defined" begin
        @test length(TestPickerMCPServer.ALL_TOOLS) == 7

        tool_names = [tool.name for tool in TestPickerMCPServer.ALL_TOOLS]
        @test "list_testfiles" in tool_names
        @test "list_testblocks" in tool_names
        @test "run_all_tests" in tool_names
        @test "run_testfiles" in tool_names
        @test "run_testblocks" in tool_names
        @test "get_testresults" in tool_names
        @test "activate_package" in tool_names
    end

    @testset "Tool parameters" begin
        # Test list_testfiles tool
        list_files =
            findfirst(t -> t.name == "list_testfiles", TestPickerMCPServer.ALL_TOOLS)
        @test list_files !== nothing
        tool = TestPickerMCPServer.ALL_TOOLS[list_files]
        @test length(tool.parameters) == 1
        @test tool.parameters[1].name == "query"
        @test tool.parameters[1].required == false

        # Test run_testfiles tool
        run_files = findfirst(t -> t.name == "run_testfiles", TestPickerMCPServer.ALL_TOOLS)
        @test run_files !== nothing
        tool = TestPickerMCPServer.ALL_TOOLS[run_files]
        @test length(tool.parameters) == 1
        @test tool.parameters[1].name == "query"
        @test tool.parameters[1].required == true

        # Test run_testblocks tool
        run_blocks =
            findfirst(t -> t.name == "run_testblocks", TestPickerMCPServer.ALL_TOOLS)
        @test run_blocks !== nothing
        tool = TestPickerMCPServer.ALL_TOOLS[run_blocks]
        @test length(tool.parameters) == 2
    end

    @testset "Tool handlers assigned" begin
        for tool in TestPickerMCPServer.ALL_TOOLS
            @test tool.handler !== nothing
            @test tool.handler isa Function
        end
    end
end
