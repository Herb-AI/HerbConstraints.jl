using HerbGrammar
@testset verbose=true "Solver" begin

    @testset "is_subdomain" begin
        domain = BitVector((1, 0, 1, 1, 1, 0, 0, 1))

        @test is_subdomain(BitVector((0, 0, 0, 0, 0, 0, 0, 0)), domain) == true
        @test is_subdomain(BitVector((0, 0, 0, 1, 0, 0, 0, 0)), domain) == true
        @test is_subdomain(BitVector((1, 0, 0, 1, 0, 0, 0, 0)), domain) == true
        @test is_subdomain(BitVector((1, 0, 1, 1, 1, 0, 0, 1)), domain) == true
        @test is_subdomain(BitVector((0, 1, 0, 0, 0, 0, 0, 0)), domain) == false
        @test is_subdomain(BitVector((0, 1, 1, 0, 1, 0, 0, 1)), domain) == false
        @test is_subdomain(BitVector((1, 1, 1, 1, 1, 1, 1, 1)), domain) == false
    end

    @testset "partition" begin
        g = @csgrammar begin
            A = 1           #1
            A = 1           #2
            A = A           #3
            A = A           #4
            A = (A, A)      #5
            A = (A, A)      #6
            A = (A, B)      #7
            A = (A, B)      #8
            B = 1           #9
            B = 1           #10
            B = (A, B)      #11
            B = (A, B)      #12
        end
        domains = partition(Hole(get_domain(g, :A)), g)
        @test length(domains) == 4
        @test domains[1] == BitVector((1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        @test domains[2] == BitVector((0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0))
        @test domains[3] == BitVector((0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0))
        @test domains[4] == BitVector((0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0))
    end
end