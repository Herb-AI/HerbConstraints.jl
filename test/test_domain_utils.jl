using HerbGrammar
@testset verbose=true "Domain Utils" begin

    @testset "is_subdomain" begin
        domain = BitVector((1, 0, 1, 1, 1, 0, 0, 1))

        #(BitVector, BitVector)
        @test is_subdomain(BitVector((0, 0, 0, 0, 0, 0, 0, 0)), domain) == true
        @test is_subdomain(BitVector((0, 0, 0, 1, 0, 0, 0, 0)), domain) == true
        @test is_subdomain(BitVector((1, 0, 0, 1, 0, 0, 0, 0)), domain) == true
        @test is_subdomain(BitVector((1, 0, 1, 1, 1, 0, 0, 1)), domain) == true
        @test is_subdomain(BitVector((0, 1, 0, 0, 0, 0, 0, 0)), domain) == false
        @test is_subdomain(BitVector((0, 1, 1, 0, 1, 0, 0, 1)), domain) == false
        @test is_subdomain(BitVector((1, 1, 1, 1, 1, 1, 1, 1)), domain) == false

        #(StateSparseSet, BitVector)
        @test is_subdomain(HerbConstraints.StateSparseSet(HerbConstraints.StateManager(), BitVector((0, 0, 0, 0, 0, 0, 0, 0))), domain) == true
        @test is_subdomain(HerbConstraints.StateSparseSet(HerbConstraints.StateManager(), BitVector((0, 0, 0, 1, 0, 0, 0, 0))), domain) == true
        @test is_subdomain(HerbConstraints.StateSparseSet(HerbConstraints.StateManager(), BitVector((1, 0, 0, 1, 0, 0, 0, 0))), domain) == true
        @test is_subdomain(HerbConstraints.StateSparseSet(HerbConstraints.StateManager(), BitVector((1, 0, 1, 1, 1, 0, 0, 1))), domain) == true
        @test is_subdomain(HerbConstraints.StateSparseSet(HerbConstraints.StateManager(), BitVector((0, 1, 0, 0, 0, 0, 0, 0))), domain) == false
        @test is_subdomain(HerbConstraints.StateSparseSet(HerbConstraints.StateManager(), BitVector((0, 1, 1, 0, 1, 0, 0, 1))), domain) == false
        @test is_subdomain(HerbConstraints.StateSparseSet(HerbConstraints.StateManager(), BitVector((1, 1, 1, 1, 1, 1, 1, 1))), domain) == false
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

    @testset "are_disjoint" begin
        #(BitVector, BitVector)
        @test are_disjoint(BitVector((1, 1, 1, 1)), BitVector((0, 0, 0, 0))) == true
        @test are_disjoint(BitVector((0, 1, 0, 0)), BitVector((0, 0, 1, 0))) == true
        @test are_disjoint(BitVector((1, 0, 0, 1)), BitVector((0, 0, 1, 0))) == true
        @test are_disjoint(BitVector((1, 1, 1, 1)), BitVector((0, 0, 1, 0))) == false
        @test are_disjoint(BitVector((0, 1, 0, 0)), BitVector((0, 1, 0, 0))) == false
        @test are_disjoint(BitVector((1, 0, 0, 1)), BitVector((1, 1, 0, 1))) == false

        #(BitVector, StateSparseSet)
        sss = HerbConstraints.StateSparseSet(HerbConstraints.StateManager(), 4)
        remove!(sss, 1)
        @test are_disjoint(BitVector((1, 0, 0, 1)), sss) == false # [1, 0, 0, 1] and [0, 1, 1, 1] overlap
        @test are_disjoint(sss, BitVector((1, 0, 0, 1))) == false
        remove!(sss, 4)
        @test are_disjoint(BitVector((1, 0, 0, 1)), sss) == true  # [1, 0, 0, 1] and [0, 1, 1, 0] are disjoint
        @test are_disjoint(sss, BitVector((1, 0, 0, 1))) == true
    end

    @testset "get_intersection" begin
        #(BitVector, BitVector)
        @test get_intersection(BitVector((1, 1, 1, 1)), BitVector((1, 1, 1, 1))) == [1, 2, 3, 4]
        @test get_intersection(BitVector((1, 0, 0, 0)), BitVector((0, 1, 1, 1))) == Vector{Int}()
        @test get_intersection(BitVector((1, 1, 1, 0)), BitVector((0, 0, 1, 1))) == [3]
        @test get_intersection(BitVector((1, 1, 1, 1)), BitVector((0, 0, 0, 1))) == [4]
        @test get_intersection(BitVector((1, 1, 1, 1)), BitVector((0, 0, 0, 0))) == Vector{Int}()

        #(BitVector, StateSparseSet). same cases, but now one of the domains is implemented with a StateSparseSet
        sss = HerbConstraints.StateSparseSet(HerbConstraints.StateManager(), 4)
        @test get_intersection(BitVector((1, 1, 1, 1)), sss) == [1, 2, 3, 4]
        @test get_intersection(sss, BitVector((1, 1, 1, 1))) == [1, 2, 3, 4]
        remove!(sss, 1)
        @test get_intersection(BitVector((1, 0, 0, 0)), sss) == Vector{Int}()
        @test get_intersection(sss, BitVector((1, 0, 0, 0))) == Vector{Int}()
        remove!(sss, 2)
        @test get_intersection(BitVector((1, 1, 1, 0)), sss) == [3]
        @test get_intersection(sss, BitVector((1, 1, 1, 0))) == [3]
        remove!(sss, 3)
        @test get_intersection(BitVector((1, 1, 1, 1)), sss) == [4]
        @test get_intersection(sss, BitVector((1, 1, 1, 1))) == [4]
        remove!(sss, 4)
        @test get_intersection(BitVector((1, 1, 1, 1)), sss) == Vector{Int}()
        @test get_intersection(sss, BitVector((1, 1, 1, 1))) == Vector{Int}()

        #(StateSparseSet, StateSparseSet)
        sss1 = HerbConstraints.StateSparseSet(HerbConstraints.StateManager(), 4)
        remove!(sss1, 1)
        sss2 = HerbConstraints.StateSparseSet(HerbConstraints.StateManager(), 4)
        remove!(sss1, 3)
        intersection = get_intersection(sss1, sss2)
        @test length(intersection) == 2
        @test 2 ∈ intersection
        @test 4 ∈ intersection
    end
end
