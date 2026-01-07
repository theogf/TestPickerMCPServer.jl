@testset "String Operations" begin
    @testset "Greeting Function" begin
        @test greet("Alice") == "Hello, Alice!"
        @test greet("Bob") == "Hello, Bob!"
        @test contains(greet("World"), "World")
    end

    @testset "Edge Cases" begin
        @test greet("") == "Hello, !"
        @test contains(greet("Test"), "Hello")
    end
end

@testset "Reverse String" begin
    @testset "Basic Reversal" begin
        @test reverse_string("hello") == "olleh"
        @test reverse_string("123") == "321"
    end

    @testset "Edge Cases" begin
        @test reverse_string("") == ""
        @test reverse_string("a") == "a"
        @test reverse_string("ab") == "ba"
    end

    @testset "Special Characters" begin
        @test reverse_string("!@#") == "#@!"
        @test reverse_string("hello world") == "dlrow olleh"
    end
end

@testset "Utility Functions" begin
    @testset "Even Number Detection" begin
        @test is_even(0) == true
        @test is_even(2) == true
        @test is_even(4) == true
    end

    @testset "Odd Number Detection" begin
        @test is_even(1) == false
        @test is_even(3) == false
        @test is_even(-1) == false
    end

    @testset "Negative Numbers" begin
        @test is_even(-2) == true
        @test is_even(-4) == true
    end
end
