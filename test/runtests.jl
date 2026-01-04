using Test

@testset "TestPickerMCPServer.jl" begin
    include("test_utils.jl")
    include("test_tools.jl")
    include("test_server.jl")
end
