@testset verbose=false "ASPSolver" begin

    @testset "tree_transformations" begin
        @testset "rulenode_to_ASP" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end

            tree = RuleNode(3, [
                RuleNode(1),
                RuleNode(4, [
                    RuleNode(1),
                    RuleNode(2)
                ])
            ])

            asp, next_index = tree_to_ASP(tree, g, 1)
            expected_asp = """
node(1,3).
child(1,1,2).
node(2,1).
child(1,2,3).
node(3,4).
child(3,1,4).
node(4,1).
child(3,2,5).
node(5,2).
"""
            @test asp == expected_asp
        end


        @testset "uniformhole_to_ASP" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end

            tree = UniformHole(BitVector((0, 0, 1, 1)), [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 0, 0)), [])
            ])

            asp, next_index = tree_to_ASP(tree, g, 1)
            expected_asp = """
1 { node(1,3);node(1,4) } 1.
child(1,1,2).
1 { node(2,1);node(2,2) } 1.
child(1,2,3).
1 { node(3,1);node(3,2) } 1.
"""
            @test asp == expected_asp
        end


        @testset "statehole_to_ASP" begin
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

            asp, next_index = tree_to_ASP(statehole, g, 1)
            expected_asp = """
1 { node(1,4);node(1,3) } 1.
child(1,1,2).
1 { node(2,1);node(2,2) } 1.
child(1,2,3).
1 { node(3,1);node(3,2);node(3,3);node(3,4) } 1.
"""
            @test asp == expected_asp
        end
    end


    @testset "constraint_transformations" begin
        @testset "constraint_rulenode_to_ASP" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end

            tree = RuleNode(3, [
                RuleNode(1),
                RuleNode(4, [
                    RuleNode(1),
                    RuleNode(2)
                ])
            ])

            asp, next_index = constraint_tree_to_ASP(g, tree, 1, 1)
            expected_asp = "node(X1,3),child(X1,1,X2),node(X2,1),child(X1,2,X3),node(X3,4),child(X3,1,X4),node(X4,1),child(X3,2,X5),node(X5,2)"
            @test asp == expected_asp
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

            asp_tree, additional = constraint_tree_to_ASP(g, tree, 1, 1)
            expected_asp = "node(X1,D1),allowed(c1x1,D1),child(X1,1,X2),node(X2,D2),allowed(c1x2,D2),child(X1,2,X3),node(X3,D3),allowed(c1x3,D3)"
            @test asp_tree == expected_asp

            expected_domains = """
allowed(c1x1,3).
allowed(c1x1,4).
allowed(c1x2,1).
allowed(c1x2,2).
allowed(c1x3,1).
allowed(c1x3,2).
"""
            @test additional == expected_domains
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

            asp_tree, additional = constraint_tree_to_ASP(g, statehole, 1, 1)
            expected_asp = "node(X1,D1),allowed(c1x1,D1),child(X1,1,X2),node(X2,D2),allowed(c1x2,D2),child(X1,2,X3),node(X3,D3),allowed(c1x3,D3)"
            @test asp_tree == expected_asp

            expected_domains = """
allowed(c1x1,4).
allowed(c1x1,3).
allowed(c1x2,1).
allowed(c1x2,2).
allowed(c1x3,1).
allowed(c1x3,2).
allowed(c1x3,3).
allowed(c1x3,4).
"""
            @test additional == expected_domains
        end        
    end

    @testset "constraint_to_ASP" begin
        @testset "forbidden_constraint_to_ASP" begin
            g = @csgrammar begin
                Number = |(1:2)
                Number = x
                Number = Number + Number
                Number = Number * Number
            end

            constraint = Forbidden(RuleNode(5, [RuleNode(3), RuleNode(3)]))

            asp = to_ASP(g, constraint, 1)
            expected_asp = ":- node(X1,5),child(X1,1,X2),node(X2,3),child(X1,2,X3),node(X3,3).\n"

            @test asp == expected_asp
        end

        @testset "contains_rulenode_constraint_to_ASP" begin
            g = @csgrammar begin
                Number = |(1:2)
                Number = x
                Number = Number + Number
                Number = Number * Number
            end
            constraint = Contains(4)
            asp = to_ASP(g, constraint, 1)
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
            asp = to_ASP(g, constraint, 1)
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
            asp = to_ASP(g, constraint, 1)
            expected_asp = "is_smaller(X,Y) :- node(X,XV),node(Y,YV),XV < YV.\nis_smaller(X,Y) :- node(X,XV),node(Y,YV),XV = YV,S = #sum { Z : child(X,Z,XC),child(Y,Z,YC),is_smaller(XC,YC) }, M = #max { Z : child(X,Z,XC) }, S = M.\n:- node(X1,5),child(X1,1,X),child(X1,2,Y),not is_smaller(X,Y).\n"

            @test asp == expected_asp
        end

        @testset "contains_subtree_constraint_to_ASP" begin
            g = @csgrammar begin
                Number = |(1:2)
                Number = x
                Number = Number + Number
                Number = Number * Number
            end
            constraint = ContainsSubtree(RuleNode(4, [UniformHole(BitVector((1, 1, 0, 0, 0)), []), RuleNode(3)]))
            asp = to_ASP(g, constraint, 1)
            expected_asp = """
allowed(c1x2,1).
allowed(c1x2,2).
subtree(c1) :- node(X1,4),child(X1,1,X2),node(X2,D2),allowed(c1x2,D2),child(X1,2,X3),node(X3,3).
:- not subtree(c1).
"""
            @test asp == expected_asp
        end
    end

    @testset "ASPSolver" begin
        @testset "asp_solver" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end

            tree = RuleNode(3, [
                RuleNode(1),
                RuleNode(4, [
                    RuleNode(1),
                    RuleNode(2)
                ])
            ])

            solver = ASPSolver(g, tree)
            solve(solver)
            @test length(solver.solutions) == 1
            expected_solution = Dict{Int64,Int64}(1 => 3, 2 => 1, 3 => 4, 4 => 1, 5 => 2)
            @test solver.solutions[1] == expected_solution
        end

        @testset "asp_solver_write_file" begin
            g = @csgrammar begin
                S = 1 | x
                S = S + S
                S = S * S
            end
            addconstraint!(g, Unique(1))
            addconstraint!(g, Unique(2))

            tree = RuleNode(4, [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 0, 0)), [])
            ])

            solver = ASPSolver(g, tree)
            solve(solver, true)

            extract_solutions_from_file(solver)
            @test length(solver.solutions) == 2
            
            expected_solution_1 = Dict{Int64,Int64}(1 => 4, 2 => 1, 3 => 2)
            expected_solution_2 = Dict{Int64,Int64}(1 => 4, 2 => 2, 3 => 1)

            @test solver.solutions[1] == expected_solution_1 || solver.solutions[1] == expected_solution_2
            @test solver.solutions[2] == expected_solution_1 || solver.solutions[2] == expected_solution_2
        end
    end
end
