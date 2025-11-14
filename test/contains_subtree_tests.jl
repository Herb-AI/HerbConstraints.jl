# @testmodule HerbGrammar begin
@testsetup module HerbGrammar
    using HerbGrammar
end

# @testmodule HerbCore begin
@testsetup module HerbCore
    using HerbCore
end


@testitem "temp" setup=[HerbGrammar] begin
    node = HerbGrammar.RuleNode(2)
    # HerbCore.eval(node)
end

@testitem "check_tree" setup=[HerbGrammar] begin 
    tree_true = HerbGrammar.RuleNode(3, [
        HerbGrammar.RuleNode(3, [
            HerbGrammar.RuleNode(1),
            HerbGrammar.RuleNode(2)
        ]),
        HerbGrammar.RuleNode(2)
    ])
    tree_false = HerbGrammar.RuleNode(3, [
        HerbGrammar.RuleNode(3, [
            HerbGrammar.RuleNode(2),
            HerbGrammar.RuleNode(2)
        ]),
        HerbGrammar.RuleNode(2)
    ])
    for with_VarNode ∈ [true, false]
        contains_subtree = ContainsSubtree(
            HerbGrammar.RuleNode(3, [
                HerbGrammar.RuleNode(1),
                # with_VarNode ? 
                VarNode(:a) 
                # : 
                # HerbGrammar.RuleNode(2)
            ])
        )

        @test check_tree(contains_subtree, tree_true) == true
        @test check_tree(contains_subtree, tree_false) == false
    end
end

@testitem "check_tree, 2 VarNodes"  setup=[HerbGrammar] begin
    contains_subtree = ContainsSubtree(
        HerbGrammar.RuleNode(3, [
            VarNode(:a),
            VarNode(:a)
        ])
    )

    tree_true = HerbGrammar.RuleNode(3, [
        HerbGrammar.RuleNode(3, [
            HerbGrammar.RuleNode(1),
            HerbGrammar.RuleNode(2)
        ]),
        HerbGrammar.RuleNode(3, [
            HerbGrammar.RuleNode(1),
            HerbGrammar.RuleNode(2)
        ]),
    ])

    tree_false = HerbGrammar.RuleNode(3, [
        HerbGrammar.RuleNode(3, [
            HerbGrammar.RuleNode(1),
            HerbGrammar.RuleNode(2)
        ]),
        HerbGrammar.RuleNode(4, [
            HerbGrammar.RuleNode(1),
            HerbGrammar.RuleNode(2)
        ]),
    ])

    @test check_tree(contains_subtree, tree_true) == true
    @test check_tree(contains_subtree, tree_false) == false
end

@testitem "propagate (UniformSolver)" setup=[HerbGrammar, HerbCore] begin
    function has_active_constraints(solver::UniformSolver)::Bool
        for c ∈ keys(solver.isactive)
            if get_value(solver.isactive[c]) == 1
                return true
            end
        end
        return false
    end

    @testset "1 VarNode" begin
        subtree = HerbGrammar.RuleNode(3, [
            HerbGrammar.RuleNode(1),
            VarNode(:a)
        ])
        grammar = HerbGrammar.@csgrammar begin
            S = 1 | x
            S = S + S
            S = S * S
        end
        HerbGrammar.addconstraint!(grammar, ContainsSubtree(subtree))

        @testset "0 candidates" begin
            # 3{1, :a} is never contained in the tree

            tree = HerbCore.UniformHole(BitVector((0, 0, 1, 1)), [
                HerbGrammar.RuleNode(2),
                HerbGrammar.RuleNode(4, [
                    HerbCore.UniformHole(BitVector((1, 1, 0, 0)), []),
                    HerbCore.UniformHole(BitVector((1, 1, 0, 0)), [])
                ])
            ])

            solver = UniformSolver(grammar, tree)
            @test !isfeasible(solver)
        end

        @testset "1 candidate" begin
            # 3{1, :a} can only appear at the root

            tree = HerbCore.UniformHole(BitVector((0, 0, 1, 1)), [
                HerbGrammar.RuleNode(1),
                HerbGrammar.RuleNode(4, [
                    HerbCore.UniformHole(BitVector((1, 1, 0, 0)), []),
                    HerbCore.UniformHole(BitVector((1, 1, 0, 0)), [])
                ])
            ])

            solver = UniformSolver(grammar, tree)
            tree = get_tree(solver)
            @test isfeasible(solver)
            @test HerbCore.isfilled(tree) && (HerbCore.get_rule(tree) == 3) # the root is filled with a 3
            @test !HerbCore.isfilled(tree.children[2].children[1]) # the other two holes remain unfilled.
            @test !HerbCore.isfilled(tree.children[2].children[2]) # the other two holes remain unfilled.
            @test !has_active_constraints(solver) # constraint is satisfied and deleted
        end

        @testset "2 candidates" begin
            # 3{1, :a} can appear at path=[] and path=[2].

            tree = HerbCore.UniformHole(BitVector((0, 0, 1, 1)), [
                HerbGrammar.RuleNode(1),
                HerbGrammar.RuleNode(3, [
                    HerbCore.UniformHole(BitVector((1, 1, 0, 0)), []),
                    HerbCore.UniformHole(BitVector((1, 1, 0, 0)), [])
                ])
            ])

            #initial propagation: softfail, all holes remain unfilled
            solver = UniformSolver(grammar, tree)
            tree = get_tree(solver)
            @test isfeasible(solver)
            @test !HerbCore.isfilled(tree)
            @test !HerbCore.isfilled(tree.children[2].children[1])
            @test !HerbCore.isfilled(tree.children[2].children[2])
            @test has_active_constraints(solver) # softfail: constraint remains active

            #remove rule 3 from the root, now 3{1, :a} can only appear at path=[2]
            remove!(solver, Vector{Int}(), 3)
            hole = tree.children[2].children[1]
            @test isfeasible(solver)
            @test HerbCore.isfilled(hole) && (HerbCore.get_rule(hole) == 1) #the hole is filled with rule 1
            @test !has_active_constraints(solver) # constraint is satisfied and deleted
        end
    end

    @testset "2 VarNode, softfails" begin
        subtree = HerbGrammar.RuleNode(3, [
            VarNode(:a),
            VarNode(:a)
        ])
        grammar = HerbGrammar.@csgrammar begin
            S = 1 | x
            S = S + S
            S = S * S
        end
        HerbGrammar.addconstraint!(grammar, ContainsSubtree(subtree))

        @testset "1 candidate, partial softfail" begin
            # 3{:a, :a} can only appear at the root
            # the first hole can be filled with a 3
            # filling the other two holes is ambiguous

            tree = HerbCore.UniformHole(BitVector((0, 0, 1, 1)), [
                HerbCore.UniformHole(BitVector((1, 1, 0, 0)), []),
                HerbCore.UniformHole(BitVector((1, 1, 0, 0)), [])
            ])

            solver = UniformSolver(grammar, tree)
            tree = get_tree(solver)
            @test isfeasible(solver)
            @test HerbCore.isfilled(tree) && (HerbCore.get_rule(tree) == 3) # the root is filled with a 3
            @test !HerbCore.isfilled(tree.children[1]) # the other two holes remain unfilled.
            @test !HerbCore.isfilled(tree.children[2]) # the other two holes remain unfilled.
            @test has_active_constraints(solver) # the constraint remains active
        end

        @testset "2 candidates, softfail" begin
            # 3{:a, :a} can appear at the root, or at child 1
            # Three out of the four possible trees are valid:
            # - 3{3{1, 1}, 4{1, 1}} VALID (contains the subtree at child 1)
            # - 3{4{1, 1}, 4{1, 1}} VALID (contains the subtree at root)
            # - 4{3{1, 1}, 4{1, 1}} VALID (contains the subtree at child 1)
            # - 4{4{1, 1}, 4{1, 1}} INVALID
            # no deductions can be made at this point.

            tree = HerbCore.UniformHole(
                BitVector((0, 0, 1, 1)),
                [
                    HerbCore.UniformHole(BitVector((0, 0, 1, 1)), [
                        HerbGrammar.RuleNode(1),
                        HerbGrammar.RuleNode(1)
                    ])
                    HerbGrammar.RuleNode(4, [
                        HerbGrammar.RuleNode(1),
                        HerbGrammar.RuleNode(1)
                    ])
                ]
            )

            solver = UniformSolver(grammar, tree)
            tree = get_tree(solver)
            @test isfeasible(solver)
            @test !HerbCore.isfilled(tree)
            @test !HerbCore.isfilled(tree.children[1])
            @test has_active_constraints(solver)
        end
    end
end

@testitem "DomainRuleNode" setup=[HerbGrammar, HerbCore] begin
    tests = [
        (
            "SoftFail large domain",
            BitVector((0, 0, 0, 1, 1, 1)), # domain_root
            BitVector((0, 0, 0, 1, 1, 1)), # domain_root_target
            BitVector((1, 1, 1, 0, 0, 0)), # domain_leaf
            BitVector((1, 1, 1, 0, 0, 0)), # domain_leaf_target
        ),
        (
            "SoftFail small domain",
            BitVector((0, 0, 0, 1, 1, 0)), # domain_root
            BitVector((0, 0, 0, 1, 1, 0)), # domain_root_target
            BitVector((1, 1, 0, 0, 0, 0)), # domain_leaf
            BitVector((1, 1, 0, 0, 0, 0)), # domain_leaf_target
        ),
        (
            "Deduction in Root",
            BitVector((0, 0, 0, 1, 0, 1)), # domain_root
            BitVector((0, 0, 0, 1, 0, 0)), # domain_root_target
            BitVector((1, 1, 0, 0, 0, 0)), # domain_leaf
            BitVector((1, 1, 0, 0, 0, 0)), # domain_leaf_target
        ),
        (
            "Deduction in Leaf",
            BitVector((0, 0, 0, 1, 1, 0)), # domain_root
            BitVector((0, 0, 0, 1, 1, 0)), # domain_root_target
            BitVector((0, 1, 1, 0, 0, 0)), # domain_leaf
            BitVector((0, 1, 0, 0, 0, 0)), # domain_leaf_target
        ),
        (
            "Deduction in Root and Leaf",
            BitVector((0, 0, 0, 1, 0, 1)), # domain_root
            BitVector((0, 0, 0, 1, 0, 0)), # domain_root_target
            BitVector((0, 1, 1, 0, 0, 0)), # domain_leaf
            BitVector((0, 1, 0, 0, 0, 0)), # domain_leaf_target
        )
    ]

    @testset "$name" for (name, domain_root, domain_root_target, domain_leaf, domain_leaf_target) ∈ tests
        grammar = HerbGrammar.@csgrammar begin
            S = 1
            S = 2
            S = 3
            S = 4, S
            S = 5, S
            S = 6, S
        end

        # must contain at least rule 4 or 5 in the root.
        # must contain at least rule 1 or 2 in the leaf. 
        HerbGrammar.addconstraint!(grammar, ContainsSubtree(DomainRuleNode(grammar, [4, 5], [
            DomainRuleNode(grammar, [1, 2])
        ])))

        tree = HerbCore.UniformHole(domain_root, [
            HerbCore.UniformHole(domain_leaf, [])
        ])
        solver = UniformSolver(grammar, tree)
        tree = get_tree(solver)

        for rule ∈ 1:6
            @test domain_root_target[rule] == tree.domain[rule]
            @test domain_leaf_target[rule] == tree.children[1].domain[rule]
        end
    end

    @testset "HardFail" begin
        grammar = HerbGrammar.@csgrammar begin
            S = 1
            S = 2
            S = 3
            S = 4
        end
        HerbGrammar.addconstraint!(grammar, ContainsSubtree(DomainRuleNode(grammar, [1, 2])))

        @test !isfeasible(UniformSolver(grammar, HerbGrammar.RuleNode(3)))
        @test !isfeasible(UniformSolver(grammar, HerbCore.UniformHole(BitVector((0, 0, 1, 1)), [])))
    end
end

@testitem "Update rule indices" setup=[HerbGrammar, HerbCore] begin #verbose = true 
    @testset "Update rule index only." begin
        expected_contains_subtree = ContainsSubtree(
            HerbGrammar.RuleNode(3, [
                VarNode(:a),
                VarNode(:a),
            ]),
        )
        tree = HerbCore.@rulenode 3{3{1,1},2}
        mapping = Dict(1 => 7, 5 => 3)
        @testset "interface without grammar" begin
            n_rules = 5
            contains_subtree = ContainsSubtree(
                HerbGrammar.RuleNode(5, [
                    VarNode(:a),
                    VarNode(:a),
                ]),
            )
            HerbCore.update_rule_indices!(contains_subtree, n_rules) # no change to HerbGrammar.RuleNode and VarNode
            @test check_tree(contains_subtree, tree) == false
            # with mapping
            constraints = [contains_subtree]
            HerbCore.update_rule_indices!(contains_subtree, n_rules, mapping, constraints)
            @test check_tree(contains_subtree, tree) == true
            @test contains_subtree.tree == expected_contains_subtree.tree
        end
        @testset "interface with grammar" begin
            grammar = HerbGrammar.@csgrammar begin
                Int = 1
                Int = x
                Int = -Int
                Int = Int + Int
                Int = Int * Int
            end
            contains_subtree = ContainsSubtree(
                HerbGrammar.RuleNode(5, [
                    VarNode(:a),
                    VarNode(:a),
                ]),
            )
            HerbCore.update_rule_indices!(contains_subtree, grammar)
            @test check_tree(contains_subtree, tree) == false
            # with mapping
            HerbCore.update_rule_indices!(contains_subtree, grammar, mapping)
            @test check_tree(contains_subtree, tree) == true
            @test contains_subtree.tree == expected_contains_subtree.tree
        end
    end
end

@testitem "is_domain_valid" setup=[HerbGrammar, HerbCore] begin #verbose = true
    grammar = HerbGrammar.@csgrammar begin
        Int = 1
        Int = x
        Int = -Int
        Int = Int + Int
        Int = Int * Int
    end
    contains_subtree = ContainsSubtree(
        HerbGrammar.RuleNode(5, [
            VarNode(:a),
            VarNode(:a),
        ]),
    )
    @test HerbCore.is_domain_valid(contains_subtree, grammar) == true
end

@testitem "issame" setup=[HerbGrammar, HerbCore]begin
    tree1 = HerbCore.UniformHole(BitVector((0, 0, 1, 1)), [
        HerbGrammar.RuleNode(1),
        HerbGrammar.RuleNode(4, [
            HerbCore.UniformHole(BitVector((1, 1, 0, 0)), []),
            HerbCore.UniformHole(BitVector((1, 1, 0, 0)), [])
        ])
    ])
    tree2 = HerbCore.UniformHole(BitVector((0, 0, 1, 1)), [
        HerbGrammar.RuleNode(1),
        HerbGrammar.RuleNode(4, [
            HerbCore.UniformHole(BitVector((1, 1, 0, 0)), []),
            HerbCore.UniformHole(BitVector((1, 1, 1, 0)), [])
        ])
    ])
    @test HerbCore.issame(ContainsSubtree(tree1), ContainsSubtree(tree1)) == true
    @test HerbCore.issame(ContainsSubtree(tree1), ContainsSubtree(tree2)) == false
end
