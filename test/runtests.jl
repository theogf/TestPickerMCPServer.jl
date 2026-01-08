using Test
using TestPickerMCPServer
using Pkg

@testset "TestPickerMCPServer.jl" begin
    include("test_utils.jl")
    include("test_config.jl")
    include("test_tools.jl")
    include("test_handlers_unit.jl")
    include("test_integration.jl")
    include("test_server_http.jl")
end
