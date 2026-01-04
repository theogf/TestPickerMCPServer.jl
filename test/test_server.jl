using TestPickerMCPServer
using Test

@testset "Server Module" begin
    @testset "Module exports" begin
        @test isdefined(TestPickerMCPServer, :start_server)
        @test TestPickerMCPServer.start_server isa Function
    end

    @testset "Module constants" begin
        @test isdefined(TestPickerMCPServer, :SERVER_PKG)
        @test isdefined(TestPickerMCPServer, :INTERFACES)
        @test isdefined(TestPickerMCPServer, :ALL_TOOLS)
    end

    @testset "Configuration function" begin
        @test isdefined(TestPickerMCPServer, :get_config)

        # Test default value
        result = TestPickerMCPServer.get_config("nonexistent_key", "default_value")
        @test result == "default_value"
    end
end
