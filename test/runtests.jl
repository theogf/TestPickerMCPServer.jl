using Test
using TestPickerMCPServer
using Pkg

# Initialize SERVER_PKG for handler and integration tests
# This mimics what start_server() does but in test context
TestPickerMCPServer.SERVER_PKG[] = try
    TestPickerMCPServer.detect_package()
catch e
    # In some CI environments, the test project might not have a name
    # In that case, we still need to set up a PackageSpec for testing
    @warn "Could not detect package automatically, using fallback" exception = e
    Pkg.Types.PackageSpec(; name = "TestPickerMCPServer", path = dirname(@__DIR__))
end

@testset "TestPickerMCPServer.jl" begin
    include("test_utils.jl")
    include("test_utils_extended.jl")
    include("test_config.jl")
    include("test_tools.jl")
    include("test_handlers.jl")
    include("test_server.jl")
    include("test_integration.jl")
end
