@testset verbose=false "Forbidden Sequence" begin
    function dummy_tree(sequence)::AbstractRuleNode
        # returns a tree that contains the specified sequence and some noise.
        # holes can be represented by tuples of indices
        if length(sequence) == 1
            if sequence[1] isa Tuple
                domain = BitVector((r ∈ sequence[1] for r ∈ 1:9))
                return Hole(domain)
            end
            return RuleNode(sequence[1])
        end
        children = [dummy_tree(sequence[2:end])]
        if sequence[1] isa Tuple
            domain = BitVector((r ∈ sequence[1] for r ∈ 1:9))
            return UniformHole(domain, children)
        end
        return RuleNode(sequence[1], children)
    end
    
    function dummy_solver(sequence, constraint)::Solver
        grammar = @csgrammar begin
            S = (S, 1) | (S, 2) | (S, 3) | (S, 4) | (S, 5) | (S, 6) | (S, 7) | (S, 8)
            S = 9
        end
        # only 1 grammar is ever instantiated (at compile time), so we need to clear the grammar
        empty!(grammar.constraints) 
        addconstraint!(grammar, constraint)
        return GenericSolver(grammar, dummy_tree(sequence))
    end
    
    function get_sequence(solver, n)
        #converts a tree into a sequence of Int (representing a rule) and Tuple{Int} (representing a domain of rules)
        sequence = []
        node = get_tree(solver)
        for _ ∈ 1:n
            if isfilled(node)
                push!(sequence, get_rule(node))
            else
                push!(sequence, Tuple(rule for rule ∈ 1:9 if node.domain[rule]))
            end
            if !isempty(get_children(node))
                node = get_children(node)[1]
            end
        end
        return sequence
    end
    
    function test_propagation(
        constraint::ForbiddenSequence, 
        sequence_before_propagation, 
        sequence_after_propagation
    )
        # An "Int" in the sequence represents a rule (RuleNode)
        # A "Tuple" in the sequence represents a domain of rules (UniformHole)
        solver = dummy_solver(sequence_before_propagation, constraint)
        actual = get_sequence(solver, length(sequence_before_propagation))
        expected = sequence_after_propagation
        @test actual == expected
    end
    
    function test_infeasible(
        constraint::ForbiddenSequence, 
        sequence_before_propagation
    )
        solver = dummy_solver(sequence_before_propagation, constraint)
        @test isfeasible(solver) == false
    end

    @testset "check_tree" begin
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
            tree2 = dummy_tree([1, 2, 9, 3])
            tree3 = dummy_tree([9, 1, 9, 2, 9, 3, 9])
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

    @testset "propagation" begin
        @testset "infeasible" begin
            constraint = ForbiddenSequence([1, 2, 3])
        
            test_infeasible(
                constraint,
                [1, 2, 3]
            )
        
            test_infeasible(
                constraint,
                [1, 2, (1, 2, 3), 3]
            )
        
            test_infeasible(
                constraint,
                [1, 2, (1, 2, 3), (1, 2, 3), 3]
            )
        
            test_infeasible(
                constraint,
                [1, 2, 3, (1, 2, 3), (1, 2, 3), 3]
            )
        end

        @testset "0 deductions" begin
            constraint = ForbiddenSequence([1, 2, 3])

            test_propagation(
                constraint,
                [(1, 2, 3), (1, 2, 3), (1, 2, 3)],
                [(1, 2, 3), (1, 2, 3), (1, 2, 3)]
            )
        end

        @testset "1 deduction" begin
            constraint = ForbiddenSequence([1, 2, 3])

            test_propagation(
                constraint,
                [(1, 2, 3), 2, 3],
                [(2, 3), 2, 3]
            )

            test_propagation(
                constraint,
                [1, (1, 2, 3), 3],
                [1, (1, 3), 3]
            )
            
            test_propagation(
                constraint,
                [1, 2, (1, 2, 3)],
                [1, 2, (1, 2)]
            )

            test_propagation(
                constraint,
                [3, 1, (4, 5, 6), 3, (1, 2, 3), 1, (4, 5, 6), 3],
                [3, 1, (4, 5, 6), 3, (1, 3), 1, (4, 5, 6), 3]
            )
        end

        @testset "2 deductions" begin
            constraint = ForbiddenSequence([1, 2, 3])

            test_propagation(
                constraint,
                [1, (1, 2, 3), (1, 2, 3), 3],
                [1, (1, 3), (1, 3), 3]
            )

            test_propagation(
                constraint,
                [1, (1, 2, 3), (1, 2, 3), 3],
                [1, (1, 3), (1, 3), 3]
            )
        end

        @testset "infeasible (with ignore_if)" begin
            constraint = ForbiddenSequence([1, 2, 3], ignore_if=[4, 5])
        
            test_infeasible(
                constraint,
                [1, 2, 3]
            )

            test_infeasible(
                constraint,
                [(1, 2, 3, 4), 1, 2, 3, (1, 2, 3, 4)]
            )
        
            test_infeasible(
                constraint,
                [1, 2, 3, 1, 2, 4, 3]
            )

            test_infeasible(
                constraint,
                [1, 2, 3, 1, 2, (1, 2, 3, 4), 3]
            )

            test_infeasible(
                constraint,
                [1, 2, 4, 3, 1, 2, 3]
            )

            test_infeasible(
                constraint,
                [1, 2, (1, 2, 3, 4), 3, 1, 2, 3]
            )
        end

        @testset "0 deductions (with ignore_if)" begin
            constraint = ForbiddenSequence([1, 2, 3], ignore_if=[4, 5])

            test_propagation(
                constraint,
                [1, 2, 4, 3],
                [1, 2, 4, 3]
            )

            test_propagation(
                constraint,
                [1, (1, 2, 3), 4, 3],
                [1, (1, 2, 3), 4, 3]
            )

            test_propagation(
                constraint,
                [1, 2, 4, (1, 2, 3)],
                [1, 2, 4, (1, 2, 3)]
            )
        end

        @testset "1 deduction (with ignore_if)" begin
            constraint = ForbiddenSequence([1, 2, 3], ignore_if=[4, 5])

            test_propagation(
                constraint,
                [1, 2, (2, 4), 3],
                [1, 2, 4, 3]
            )

            test_propagation(
                constraint,
                [1, (1, 2, 3), 3, 1, 2, 4, 3],
                [1, (1, 3), 3, 1, 2, 4, 3]
            )

            test_propagation(
                constraint,
                [1, 2, 4, 3, 1, (1, 2, 3), 3],
                [1, 2, 4, 3, 1, (1, 3), 3]
            )
        end

        @testset "ignore_if" begin
            constraint = ForbiddenSequence([1, 2, 3], ignore_if=[4, 5, 6, 7, 8])

            test_propagation(
                constraint,
                [1, 2, (1, 2, 3, 4, 5), 3],
                [1, 2, (4, 5), 3]
            )
        end
    end
end
