@testitem "ASPSolver" tags = [:asp] begin
    using HerbCore, HerbGrammar
    using Clingo_jll

    using HerbConstraints: grammar_to_ASP, constraint_to_ASP, rulenode_to_ASP,
        constraint_rulenode_to_ASP, ASPSolver, isfeasible, get_grammar
    using HerbConstraints
    using TestSetExtensions: ExtendedTestSet
    using ReferenceTests

    @testset ExtendedTestSet "rulenode_transformations" begin
        @testset ExtendedTestSet "single rule no children" begin
            tree = RuleNode(1)

            asp, next_index = rulenode_to_ASP(tree, 1)
            @test_reference "asp_output/single_rulenode_no_children.lp" asp
            @test next_index == 2
        end
        @testset "rulenode_to_ASP" begin
            tree = RuleNode(3, [
                RuleNode(1),
                RuleNode(4, [
                    RuleNode(1),
                    RuleNode(2)
                ])
            ])

            asp, next_index = rulenode_to_ASP(tree, 1)
            @test_reference "asp_output/larger_rulenode.lp" asp
            @test next_index == 6
        end

        @testset "uniformhole_to_ASP" begin
            tree = UniformHole(BitVector((0, 0, 1, 1)), [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 0, 0)), [])
            ])

            asp, next_index = rulenode_to_ASP(tree, 1)
            @test_reference "asp_output/uniform_hole.lp" asp
            @test next_index == 4
        end

        @testset "statehole_to_ASP" begin
            tree = UniformHole(BitVector((0, 0, 1, 1)), [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 1, 1)), [])
            ])
            sm = HerbConstraints.StateManager()
            statehole = HerbConstraints.StateHole(sm, tree)

            asp, next_index = rulenode_to_ASP(statehole, 1)
            @test_reference "asp_output/statehole.lp" asp
        end
    end


    @testset ExtendedTestSet "constraint_transformations" begin
        @testset "constraint_rulenode_to_ASP" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end

            tree = UniformHole(BitVector((0, 0, 1, 1)), [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 0, 0)), [])
            ])

            c = Unique(4)
            addconstraint!(g, c)

            asp, next_index = constraint_rulenode_to_ASP(tree, 1)
            @test_reference "asp_output/unique_constraint_rulenode.lp" asp
            @test next_index == 4
        end

        @testset "constraint_uniformhole_to_ASP" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end

            tree = UniformHole(BitVector((0, 0, 1, 1)), [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 0, 0)), [])
            ])

            c = ContainsSubtree(UniformHole(BitVector((0, 0, 1, 1)), [
                RuleNode(1),
                RuleNode(2)
            ]))
            addconstraint!(g, c)
            asp_tree, node_index = constraint_rulenode_to_ASP(tree, 1)
            @test_reference "asp_output/containssubtree_constraint_rulenode.lp" asp_tree
            @test node_index == 4
        end

        @testset "constraint_statehole_to_ASP" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end

            tree = UniformHole(BitVector((0, 0, 1, 1)), [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 1, 1)), [])
            ])
            sm = HerbConstraints.StateManager()
            statehole = HerbConstraints.StateHole(sm, tree)

            c = ContainsSubtree(RuleNode(4, [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 1, 1)), [])
            ])) # children are not included
            addconstraint!(g, c; allow_empty_children=true)

            asp_tree, node_index = constraint_rulenode_to_ASP(statehole, 1)
            @test_reference "asp_output/contains_subtree_constraint_statehole.lp" asp_tree
            @test node_index == 4
        end


        @testset "constraint_single_varnode_to_ASP" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end
            tree = UniformHole(BitVector((0, 0, 1, 1)), [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 1, 1)), [])
            ])
            c = Forbidden(VarNode(:a))
            addconstraint!(g, c; allow_empty_children=true)

            asp_tree, node_index = constraint_rulenode_to_ASP(tree, 1)
            @test_reference "asp_output/forbidden_constraint_varnode.lp" asp_tree
            @test node_index == 4
        end
    end

    @testset ExtendedTestSet "constraint_to_ASP" begin
        @testset "forbidden_constraint_to_ASP" begin
            g = @csgrammar begin
                Number = |(1:2)
                Number = x
                Number = Number + Number
                Number = Number * Number
            end

            constraint = Forbidden(RuleNode(5, [RuleNode(3), RuleNode(3)]))
            addconstraint!(g, constraint)

            asp = constraint_to_ASP(constraint, 1)
            @test_reference "asp_output/forbidden_constraint.lp" asp
        end

        @testset "contains_rulenode_constraint_to_ASP" begin
            g = @csgrammar begin
                Number = |(1:2)
                Number = x
                Number = Number + Number
                Number = Number * Number
            end
            constraint = Contains(4)
            addconstraint!(g, constraint)
            asp = constraint_to_ASP(constraint, 1)
            expected_asp = ":- not node(_,4).\n"

            @test asp == expected_asp
        end

        @testset "unique_constraint_to_ASP" begin
            g = @csgrammar begin
                Number = |(1:2)
                Number = x
                Number = Number + Number
                Number = Number * Number
            end
            constraint = Unique(5)
            addconstraint!(g, constraint)
            asp = constraint_to_ASP(constraint, 1)
            expected_asp = "{ node(X,5) : node(X,5) } 1.\n"

            @test asp == expected_asp
        end

        @testset "ordered_constraint_to_ASP" begin
            g = @csgrammar begin
                Number = |(1:2)
                Number = x
                Number = Number + Number
                Number = Number * Number
            end
            constraint = Ordered(RuleNode(5, [VarNode(:X), VarNode(:Y)]), [:X, :Y])
            addconstraint!(g, constraint)
            asp = constraint_to_ASP(constraint, 1)
            @test_reference "asp_output/ordered_constraint.lp" asp
        end

    end

    @testset ExtendedTestSet "Solver struct" begin
        @testset "asp_solver_uniform_holes" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end
            addconstraint!(g, Unique(1); allow_empty_children=true)
            addconstraint!(g, Unique(2); allow_empty_children=true)

            tree = UniformHole(BitVector((0, 0, 1, 1)), [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 0, 0)), [])
            ])

            solver = ASPSolver(g, tree)
            @test length(solver.solutions) == 4

            @test Dict{Int64,Int64}(1 => 3, 2 => 1, 3 => 2) in solver.solutions
            @test Dict{Int64,Int64}(1 => 3, 2 => 2, 3 => 1) in solver.solutions
            @test Dict{Int64,Int64}(1 => 4, 2 => 1, 3 => 2) in solver.solutions
            @test Dict{Int64,Int64}(1 => 4, 2 => 2, 3 => 1) in solver.solutions
        end

        @testset "asp_solver_filled_rulenode" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end

            tree = RuleNode(3, [
                RuleNode(4, [
                    RuleNode(1),
                    RuleNode(2)
                ]),
                RuleNode(3, [
                    RuleNode(1),
                    RuleNode(2)
                ]),
            ])

            solver = ASPSolver(g, tree)
            @test length(solver.solutions) == 1
        end

        @testset "asp_solver_filled_rulenode_constraints" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end
            addconstraint!(g, Unique(1); allow_empty_children=true)
            addconstraint!(g, Unique(2); allow_empty_children=true)

            tree = RuleNode(3, [
                RuleNode(4, [
                    RuleNode(1),
                    RuleNode(2)
                ]),
                RuleNode(3, [
                    RuleNode(1),
                    RuleNode(2)
                ]),
            ])

            solver = ASPSolver(g, tree)
            @test length(solver.solutions) == 0
            @test isfeasible(solver) == false
        end

        @testset "asp_solver_non_uniform" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end

            tree = Hole(BitVector([1, 1, 1, 1]))

            try
                solver = ASPSolver(g, tree)
            catch AssertionError
                @test true
            end
        end

        @testset "asp_solver_properties" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end

            tree = UniformHole(BitVector((0, 0, 1, 1)), [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 0, 0)), [])
            ])

            solver = ASPSolver(g, tree)
            @test get_grammar(solver) === g
            @test get_tree(solver) === tree
            @test HerbConstraints.get_name(solver) == "ASPSolver"
            @test isfeasible(solver) === true
        end
    end
    @testset "Full pipeline" begin
        @testset ExtendedTestSet "Single solution, single derivation rule" begin
            g = @csgrammar begin
                S = 1
            end

            tree = UniformHole(BitVector((1,)))

            asp_solver = @test_nowarn ASPSolver(g, tree)
            @test isfeasible(asp_solver)
            @test length(asp_solver.solutions) == 1
            @test asp_solver.solutions[1] == Dict(1 => 1)
        end

        @testset ExtendedTestSet "No solutions (ordered constraint)" begin
            grammar = @csgrammar begin
                Number = 1
                Number = x
                Number = Number + Number
                Number = Number - Number
            end
            constraint1 = Ordered(RuleNode(3, [
                    VarNode(:a),
                    VarNode(:b)
                ]), [:a, :b])
            constraint2 = Ordered(RuleNode(4, [
                    VarNode(:a),
                    VarNode(:b)
                ]), [:a, :b])
            addconstraint!(grammar, constraint1)
            addconstraint!(grammar, constraint2)

            tree = UniformHole(BitVector((0, 0, 1, 1)), [
                UniformHole(BitVector((0, 0, 1, 1)), [
                    UniformHole(BitVector((1, 1, 0, 0)), []),
                    UniformHole(BitVector((1, 1, 0, 0)), [])
                ]),
                UniformHole(BitVector((1, 1, 0, 0)), [])
            ])
            asp_solver = @test_nowarn ASPSolver(grammar, tree)
            @test !isfeasible(asp_solver)
            @test length(asp_solver.solutions) == 0
        end

        @testset ExtendedTestSet "No solutions (forbidden constraint)" begin
            grammar = @csgrammar begin
                Number = 1
                Number = x
                Number = Number + Number
                Number = Number - Number
            end
            constraint1 = Forbidden(RuleNode(3, [
                VarNode(:a),
                VarNode(:b)
            ]))
            constraint2 = Forbidden(RuleNode(4, [
                VarNode(:a),
                VarNode(:b)
            ]))
            addconstraint!(grammar, constraint1)
            addconstraint!(grammar, constraint2)

            constraint_tree_asp = grammar_to_ASP(grammar)
            @test_reference "asp_output/grammar_with_forbidden.lp" constraint_tree_asp

            tree = UniformHole(BitVector((0, 0, 1, 1)), [
                UniformHole(BitVector((0, 0, 1, 1)), [
                    UniformHole(BitVector((1, 1, 0, 0)), []),
                    UniformHole(BitVector((1, 1, 0, 0)), [])
                ]),
                UniformHole(BitVector((1, 1, 0, 0)), [])
            ])

            asp_tree, _ = rulenode_to_ASP(tree, 1)
            @test_reference "asp_output/many_uniform_holes.lp" asp_tree

            asp_solver = @test_nowarn ASPSolver(grammar, tree)
            @test !isfeasible(asp_solver)
            @test length(asp_solver.solutions) == 0
        end

        @testset "varnode_same_symbol" begin
            tree = RuleNode(3, [
                VarNode(:a),
                VarNode(:a)
            ])
            asp_tree, next_index = constraint_rulenode_to_ASP(tree, 1)
            @test_reference "asp_output/two_varnode_with_same_symbol.lp" asp_tree
            @test next_index == 4
        end

        @testset ExtendedTestSet "ordered_constraint_three_children_order" begin
            g = @csgrammar begin
                S = 1 | 2 | 3
                S = S + S + S
            end
            tree = RuleNode(4, [
                UniformHole(BitVector((1, 1, 1, 0)), []),
                UniformHole(BitVector((1, 1, 1, 0)), []),
                UniformHole(BitVector((1, 1, 1, 0)), [])
            ])
            c1 = Ordered(RuleNode(4, [
                    VarNode(:a),
                    VarNode(:b),
                    VarNode(:c)
                ]), [:b, :c, :a])

            addconstraint!(g, c1)

            asp_tree = grammar_to_ASP(g)
            @test_reference "asp_output/ordered_with_three_children.lp" asp_tree

            solver = @test_nowarn ASPSolver(g, tree)
            @test 10 == length(solver.solutions)
            @testset "Check order" for sol in solver.solutions
                @test sol[1] == 4
                @test sol[3] <= sol[4] <= sol[2]
            end
        end

        @testset ExtendedTestSet "constraints_with_varnode" begin
            grammar = @csgrammar begin
                Number = 1
                Number = x
                Number = Number + Number
                Number = Number - Number
            end
            constraint1 = Ordered(RuleNode(3, [
                    VarNode(:a),
                    VarNode(:b)
                ]), [:a, :b])
            constraint2 = Forbidden(RuleNode(3, [
                VarNode(:a),
                VarNode(:a)
            ]))
            addconstraint!(grammar, constraint1)
            addconstraint!(grammar, constraint2)

            tree = RuleNode(3, [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 0, 0)), [])
            ])

            asp_tree = grammar_to_ASP(grammar)
            @test_reference "asp_output/ordered_and_forbidden.lp" asp_tree

            solver = @test_nowarn ASPSolver(grammar, tree)
            @test length(solver.solutions) == 1
            @test solver.solutions[1] == Dict(1 => 3, 2 => 1, 3 => 2)
        end
        @testset ExtendedTestSet "Forbidden with {a,a} pattern" begin
            grammar = @csgrammar begin
                Number = 1
                Number = x
                Number = Number + Number
            end
            constraint = Forbidden(RuleNode(3, [
                VarNode(:a),
                VarNode(:a)
            ]))
            addconstraint!(grammar, constraint)

            tree = RuleNode(3, [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 0, 0)), [])
            ])

            asp_tree = grammar_to_ASP(grammar)
            @test_reference "asp_output/forbidden_with_two_matching_varnodes.lp" asp_tree

            solver = @test_nowarn ASPSolver(grammar, tree)
            @test length(solver.solutions) == 2
            @test Dict(1 => 3, 2 => 1, 3 => 2) ∈ solver.solutions
            @test Dict(1 => 3, 2 => 2, 3 => 1) ∈ solver.solutions
        end
    end
end

@testitem "Alias rule issue" tags = [:asp] begin
    import HerbCore: @rulenode
    import HerbGrammar: @csgrammar, addconstraint!
    import HerbConstraints: Forbidden, VarNode, constraint_rulenode_to_ASP, grammar_to_ASP, rulenode_to_ASP
    import TestSetExtensions: ExtendedTestSet

    @testset ExtendedTestSet "Alias rule failing" begin
        g_alias = @csgrammar begin
            Expr = Expr + Expr
            Expr = Const | Var
            Const = 0 | 1 | 2
            Var = X
        end
        g_no = @csgrammar begin
            Expr = Expr + Expr
            Expr = 0 | 1 | 2
        end

        drn_alias = DomainRuleNode(g_alias, [1], [VarNode(:x), (@rulenode 2{4})])
        constraint = Forbidden(drn_alias)
        addconstraint!(g_alias, constraint)

        drn_no = DomainRuleNode(g_no, [1], [VarNode(:x), (@rulenode 2)])
        constraint = Forbidden(drn_no)
        addconstraint!(g_no, constraint)

        asp_drn_alias = constraint_rulenode_to_ASP(drn_alias, 1)
        asp_drn_no = constraint_rulenode_to_ASP(drn_no, 1)

        @test asp_drn_alias != asp_drn_no
    end
end

@testitem "Matching varnodes problem" tags = [:asp] begin
    using HerbGrammar, HerbConstraints
    using HerbConstraints: constraint_rulenode_to_ASP
    using HerbSearch: BFSASPIterator
    using Clingo_jll

    g = @csgrammar begin
        Const = 0
        Entity = X
        Expr = Const | Entity
        Expr = Expr + Expr
    end
    drn = HerbConstraints.DomainRuleNode(g, [5], [VarNode(:a), VarNode(:a)])
    f = Forbidden(drn)
    addconstraint!(g, f)
    crn_asp, _ = constraint_rulenode_to_ASP(drn, 1)
    @test occursin("is_same", crn_asp)
    addconstraint!(g, f)

    bfs_programs = rulenode2expr.([freeze_state(p) for p ∈ BFSASPIterator(g, :Expr, max_depth=3)], (g,))
    @test :(X + 0) in bfs_programs
    @test !(:(X + X) in bfs_programs)
    @test !(:(0 + 0) in bfs_programs)
end

@testitem "Contains subtree ASP" tags = [:asp] begin
    using HerbGrammar, HerbCore
    using HerbConstraints: grammar_to_ASP, constraint_to_ASP, rulenode_to_ASP,
        constraint_rulenode_to_ASP, ASPSolver, isfeasible, get_grammar, solve
    using Clingo_jll
    using ReferenceTests

    g = @csgrammar begin
        Number = |(1:2)
        Number = x
        Number = Number + Number
        Number = Number * Number
    end
    constraint = ContainsSubtree(RuleNode(4, [UniformHole(BitVector((1, 1, 0, 0, 0)), []), RuleNode(3)]))
    addconstraint!(g, constraint)
    asp = constraint_to_ASP(constraint, 1)
    @test_reference "asp_output/contains_subtree_constraint.lp" asp

    uh = UniformHole(get_domain(g, [5]), [UniformHole(get_domain(g, [2])), UniformHole(get_domain(g, [3]))])
    solver = ASPSolver(g, uh)
    @test isempty(solver.solutions)

    uh = UniformHole(get_domain(g, [4]), [UniformHole(get_domain(g, [2])), UniformHole(get_domain(g, [3]))])
    solver = ASPSolver(g, uh)
    @test length(solver.solutions) == 1
end

@testitem "Forbidden ASP" tags = [:asp] begin
    using HerbGrammar, HerbCore
    using HerbConstraints: constraint_to_ASP, constraint_rulenode_to_ASP, ASPSolver
    using Clingo_jll
    using ReferenceTests
    using TestSetExtensions

    @testset ExtendedTestSet "Forbidden" begin
        g = @csgrammar begin
            S = 1 | x
            S = S + S
            S = S * S
        end

        tree = UniformHole(BitVector((0, 0, 1, 1)), [
            VarNode(:a),
            VarNode(:b)
        ])

        c = Forbidden(tree)
        addconstraint!(g, c)
        asp_tree, node_index = constraint_rulenode_to_ASP(tree, 1)
        @test_reference "asp_output/forbidden_a_b_constraint_tree.lp" asp_tree
        @test node_index == 4
        asp_constraint = constraint_to_ASP(c, 1)
        @test_reference "asp_output/forbidden_a_b.lp" asp_constraint
        uh = UniformHole(BitVector((0, 0, 1, 1)), [
            UniformHole(BitVector((1, 1, 0, 0)), []),
            UniformHole(BitVector((1, 1, 1, 1)), [])
        ])
        solver = ASPSolver(g, uh)
        @test isempty(solver.solutions)
        uh = UniformHole(get_domain(g, [1, 2]))
        solver = ASPSolver(g, uh)
        @test length(solver.solutions) == 2
    end
end
