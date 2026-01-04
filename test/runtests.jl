using TestPickerMCPServer
using Test

@testset "TestPickerMCPServer.jl" begin
    @test TestPickerMCPServer.hello_world() == "Hello, World!"
end
