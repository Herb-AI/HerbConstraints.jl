@testitem "LocalContainsSubtree helper constructor" begin
    using HerbCore, HerbGrammar, HerbConstraints

    grammar = @csgrammar begin
        S = 1 | x
        S = S + S
        S = S * S
    end

    @testset "stateful fields are left uninitialised" begin
        c = LocalContainsSubtree(Int[], RuleNode(1))
        @test isnothing(c.candidates)
        @test isnothing(c.indices)
    end

    @testset "a single candidate is propagated to the target subtree" begin
        tree = UniformHole(BitVector((1, 1, 0, 0)), [])
        solver = UniformSolver(grammar, tree)
        HerbConstraints.post!(solver, LocalContainsSubtree(Int[], RuleNode(1)))
        @test isfeasible(solver)
        @test isfilled(get_tree(solver))
        @test get_rule(get_tree(solver)) == 1
    end

    @testset "no candidate makes the solver infeasible" begin
        tree = UniformHole(BitVector((1, 1, 0, 0)), [])
        solver = UniformSolver(grammar, tree)
        subtree = RuleNode(3, [RuleNode(1), RuleNode(1)])
        HerbConstraints.post!(solver, LocalContainsSubtree(Int[], subtree))
        @test !isfeasible(solver)
    end

    @testset "multiple candidates are tracked by the stateful index set" begin
        tree = UniformHole(BitVector((0, 0, 1, 1)), [
            UniformHole(BitVector((1, 1, 0, 0)), []),
            UniformHole(BitVector((1, 1, 0, 0)), []),
        ])
        solver = UniformSolver(grammar, tree)
        c = LocalContainsSubtree(Int[], RuleNode(1))
        HerbConstraints.post!(solver, c)
        @test isfeasible(solver)
        @test !isnothing(c.indices)
        @test size(c.indices) == 2
        @test length(c.candidates) == 2
    end
end
