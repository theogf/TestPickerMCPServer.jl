using TestPickerMCPServer
using Test
using Preferences

@testset "Configuration System" begin
    @testset "get_config - default value" begin
        result = TestPickerMCPServer.get_config("nonexistent_key", "default")
        @test result == "default"
    end

    @testset "get_config - environment variable" begin
        # Set environment variable
        ENV["TESTPICKER_MCP_TEST_KEY"] = "env_value"
        result = TestPickerMCPServer.get_config("test_key", "default")
        @test result == "env_value"

        # Cleanup
        delete!(ENV, "TESTPICKER_MCP_TEST_KEY")
    end

    @testset "get_config - transport defaults" begin
        result = TestPickerMCPServer.get_config("transport", "stdio")
        @test result in ["stdio", "http"]

        result = TestPickerMCPServer.get_config("host", "127.0.0.1")
        @test result isa String

        result = TestPickerMCPServer.get_config("port", "3000")
        @test result isa String
    end

    @testset "get_config - precedence (ENV over default)" begin
        ENV["TESTPICKER_MCP_PRECEDENCE_TEST"] = "from_env"
        result = TestPickerMCPServer.get_config("precedence_test", "default_val")
        @test result == "from_env"

        # Cleanup
        delete!(ENV, "TESTPICKER_MCP_PRECEDENCE_TEST")
    end
end
