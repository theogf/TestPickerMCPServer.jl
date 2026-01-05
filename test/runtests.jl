using Test
using TestPickerMCPServer
using Pkg

@testset "TestPickerMCPServer.jl" begin
    include("test_utils.jl")
    include("test_utils_extended.jl")
    include("test_config.jl")
    include("test_tools.jl")
    include("test_handlers.jl")
    include("test_server.jl")
    include("test_integration.jl")
end
