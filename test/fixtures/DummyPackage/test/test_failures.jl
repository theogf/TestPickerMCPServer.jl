# This test file contains intentional failures and errors for testing purposes
# These tests are expected to fail/error when run
using Test
using DummyPackage


@testset "Intentional Failures" begin
    @testset "Arithmetic Failures" begin
        # These assertions will fail
        @test add(2, 3) == 6  # Should be 5
        @test multiply(3, 4) == 11  # Should be 12
    end

    @testset "Logic Failures" begin
        @test is_even(3) == true  # 3 is odd
        @test is_even(2) == false  # 2 is even
    end
end

@testset "Error Cases" begin
    @testset "Undefined Function" begin
        # This will cause an error - undefined function
        @test nonexistent_function(5) == 10
    end

    @testset "Type Errors" begin
        # This will cause a type error
        @test add("hello", "world") == "helloworld"
    end
end

@testset "Another Failure Group" begin
    @testset "String Operation Failures" begin
        @test reverse_string("test") == "test"  # Should be "tset"
    end

    @testset "Function Output Failures" begin
        @test greet("name") == "Hi, name!"  # Should be "Hello, name!"
        @test greet("Alice") == "Hi, Alice!"  # Should be "Hello, Alice!"
    end

    @testset "Number Check Failures" begin
        @test is_even(5) == true  # 5 is odd
        @test is_even(10) == false  # 10 is even
    end
end
