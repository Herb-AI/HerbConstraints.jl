using HerbGrammar
@testset verbose=true "Solver" begin

    @testset "Is subdomain" begin
        domain = BitVector((1, 0, 1, 1, 1, 0, 0, 1))

        @test is_subdomain(BitVector((0, 0, 0, 0, 0, 0, 0, 0)), domain) == true
        @test is_subdomain(BitVector((0, 0, 0, 1, 0, 0, 0, 0)), domain) == true
        @test is_subdomain(BitVector((1, 0, 0, 1, 0, 0, 0, 0)), domain) == true
        @test is_subdomain(BitVector((1, 0, 1, 1, 1, 0, 0, 1)), domain) == true
        @test is_subdomain(BitVector((0, 1, 0, 0, 0, 0, 0, 0)), domain) == false
        @test is_subdomain(BitVector((0, 1, 1, 0, 1, 0, 0, 1)), domain) == false
        @test is_subdomain(BitVector((1, 1, 1, 1, 1, 1, 1, 1)), domain) == false
    end

end