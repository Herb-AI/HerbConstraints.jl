@testset verbose=false "Unique" begin
    grammar = @csgrammar begin
        Number = x | 1
        Number = Number + Number
        Number = Number - Number
    end

    unique1 = Unique(1)
    addconstraint!(grammar, unique1)

    @testset "check_tree" begin
        tree_two_leaves = RuleNode(3, [
            RuleNode(3, [
                RuleNode(1),
                RuleNode(2)
            ]),
            RuleNode(3, [
                RuleNode(2),
                RuleNode(1)
            ])
        ])

        tree_two_inner = RuleNode(3, [
            RuleNode(1, [
                RuleNode(2),
                RuleNode(2)
            ]),
            RuleNode(1, [
                RuleNode(2),
                RuleNode(2)
            ])
        ])
        
        tree_one_leaf = RuleNode(3, [
            RuleNode(3, [
                RuleNode(1),
                RuleNode(2)
            ]),
            RuleNode(3, [
                RuleNode(2),
                RuleNode(2)
            ])
        ])

        tree_one_inner = RuleNode(3, [
            RuleNode(1, [
                RuleNode(2),
                RuleNode(2)
            ]),
            RuleNode(3, [
                RuleNode(2),
                RuleNode(2)
            ])
        ])

        tree_zero = RuleNode(3, [
            RuleNode(3, [
                RuleNode(2),
                RuleNode(2)
            ]),
            RuleNode(3, [
                RuleNode(2),
                RuleNode(2)
            ])
        ])

        @test check_tree(unique1, tree_two_leaves) == false
        @test check_tree(unique1, tree_two_inner) == false

        @test check_tree(unique1, tree_one_leaf) == true
        @test check_tree(unique1, tree_one_inner) == true
        @test check_tree(unique1, tree_zero) == true
    end

    @testset "propagate infeasible" begin
        node = RuleNode(3, [
            RuleNode(1),
            RuleNode(1)
        ])
        @test !isfeasible(GenericSolver(grammar, node))

        node_with_holes = RuleNode(3, [
            RuleNode(3, [
                Hole(BitVector((1, 1, 1, 1))),
                RuleNode(1)
            ]),
            RuleNode(3, [
                RuleNode(1),
                Hole(BitVector((1, 1, 1, 1)))
            ])
        ])
        @test !isfeasible(GenericSolver(grammar, node_with_holes))
    end

    @testset "propagate softfail" begin
        node_with_holes = RuleNode(3, [
            RuleNode(3, [
                Hole(BitVector((true, true, true, true))),
                RuleNode(2)
            ]),
            RuleNode(3, [
                RuleNode(2),
                Hole(BitVector((true, true, true, true)))
            ])
        ])
        solver = GenericSolver(grammar, node_with_holes)
        tree = get_tree(solver)
        @test isfeasible(solver)
        @test number_of_holes(tree) == 2
        @test length(findall(get_node_at_location(tree, [1, 1]).domain)) == 4
        @test length(findall(get_node_at_location(tree, [2, 2]).domain)) == 4
    end

    @testset "propagate deduction" begin
        node_with_holes = RuleNode(3, [
            RuleNode(3, [
                Hole(BitVector((true, true, true, true))),
                RuleNode(2)
            ]),
            RuleNode(3, [
                RuleNode(1), #a 1 is present, so all 1s from other holes must be removed
                Hole(BitVector((true, true, true, true)))
            ])
        ])
        solver = GenericSolver(grammar, node_with_holes)
        tree = get_tree(solver)
        @test isfeasible(solver)
        @test number_of_holes(tree) == 2
        @test length(findall(get_node_at_location(tree, [1, 1]).domain)) == 3
        @test length(findall(get_node_at_location(tree, [2, 2]).domain)) == 3
    end
end
