@testset "Addition" begin
    @testset "Positive Numbers" begin
        @test add(2, 3) == 5
        @test add(10, 20) == 30
        @test add(1, 1) == 2
    end

    @testset "Zero Cases" begin
        @test add(0, 0) == 0
        @test add(5, 0) == 5
        @test add(0, 10) == 10
    end

    @testset "Negative Numbers" begin
        @test add(-5, 10) == 5
        @test add(-1, -1) == -2
        @test add(-10, -5) == -15
    end

    @testset "Floating Point" begin
        @test add(1.5, 2.5) == 4.0
        @test add(0.1, 0.2) ≈ 0.3
    end
end

@testset "Multiplication" begin
    @testset "Positive Numbers" begin
        @test multiply(2, 3) == 6
        @test multiply(5, 4) == 20
        @test multiply(1, 1) == 1
    end

    @testset "With Zero" begin
        @test multiply(0, 100) == 0
        @test multiply(50, 0) == 0
        @test multiply(0, 0) == 0
    end

    @testset "Negative Numbers" begin
        @test multiply(-2, 5) == -10
        @test multiply(-3, -4) == 12
        @test multiply(-1, -1) == 1
    end

    @testset "Floating Point" begin
        @test multiply(1.5, 2.0) == 3.0
        @test multiply(2.5, 4.0) == 10.0
    end
end

@testset "Integer Operations" begin
    @testset "Combined Operations" begin
        @test add(10, 20) == 30
        @test multiply(10, 20) == 200
        @test add(multiply(2, 3), 4) == 10
    end

    @testset "Associativity" begin
        @test add(add(1, 2), 3) == add(1, add(2, 3))
        @test multiply(multiply(2, 3), 4) == multiply(2, multiply(3, 4))
    end
end
