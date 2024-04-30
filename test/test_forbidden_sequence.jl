@testset verbose=false "Forbidden Sequence" begin
    function dummy_tree(sequence::Vector{Int})::RuleNode
        #returns a tree that contains the specified sequence and some noise in the form of 99 nodes.
        if length(sequence) == 1
            return RuleNode(sequence[1])
        end
        return RuleNode(sequence[1], [
            RuleNode(99),
            RuleNode(99),
            dummy_tree(sequence[2:end]),
            RuleNode(99)
        ])
    end

    @testset "Valid trees" begin
        constraint = ForbiddenSequence([1, 2, 3])

        tree1 = dummy_tree([1, 3, 2])
        tree2 = dummy_tree([3, 2, 1])
        tree3 = dummy_tree([1, 2, 1, 2, 1, 2])

        @test check_tree(constraint, tree1) == true
        @test check_tree(constraint, tree2) == true
        @test check_tree(constraint, tree3) == true
    end

    @testset "Invalid trees" begin
        constraint = ForbiddenSequence([1, 2, 3])

        tree1 = dummy_tree([1, 2, 3])
        tree2 = dummy_tree([1, 2, 99, 3])
        tree3 = dummy_tree([99, 1, 99, 2, 99, 3, 99])
        tree4 = dummy_tree([1, 2, 1, 2, 3])
        tree5 = dummy_tree([3, 2, 1, 1, 2, 3])
        tree6 = dummy_tree([1, 1, 2, 2, 3, 3])
        
        @test check_tree(constraint, tree1) == false
        @test check_tree(constraint, tree2) == false
        @test check_tree(constraint, tree3) == false
        @test check_tree(constraint, tree4) == false
        @test check_tree(constraint, tree5) == false
        @test check_tree(constraint, tree6) == false
    end

    @testset "Valid trees (ignore_if)" begin
        constraint = ForbiddenSequence([1, 2, 3], ignore_if=[4, 5, 6])

        tree1 = dummy_tree([1, 2, 5, 3])
        tree2 = dummy_tree([5, 1, 5, 2, 5, 3, 1])
        
        @test check_tree(constraint, tree1) == true
        @test check_tree(constraint, tree2) == true
    end

    @testset "Invalid trees (ignore_if)" begin
        constraint = ForbiddenSequence([1, 2, 3], ignore_if=[4, 5, 6])

        tree1 = dummy_tree([1, 2, 3])
        tree2 = dummy_tree([5, 1, 2, 3])
        tree3 = dummy_tree([1, 2, 3, 5])
        tree4 = dummy_tree([1, 2, 5, 3, 1, 2, 3])
        tree5 = dummy_tree([1, 2, 5, 1, 2, 3])
        tree6 = dummy_tree([1, 2, 3, 5, 3])
        tree7 = dummy_tree([1, 5, 1, 2, 3])
        
        @test check_tree(constraint, tree1) == false
        @test check_tree(constraint, tree2) == false
        @test check_tree(constraint, tree3) == false
        @test check_tree(constraint, tree4) == false
        @test check_tree(constraint, tree5) == false
        @test check_tree(constraint, tree6) == false
        @test check_tree(constraint, tree7) == false
    end
end
