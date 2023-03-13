
@testset verbose=true "Propagators" begin

    g₁ = @csgrammar begin
        Real = |(1:9)
        Real = Real + Real
        Real = Real * Real
    end

    @testset "Propagating comesafter" begin
        constraint = ComesAfter(1, [9])
        context = GrammarContext(RuleNode(10, [Hole(get_domain(g₁, :Real)), Hole(get_domain(g₁, :Real))]), [1])
        domain = propagate(constraint, g₁, context, Vector(1:9))
        @test domain == Vector(2:9)
    end

    @testset "Propagating ordered" begin
        constraint = Ordered([2, 1])
        context = GrammarContext(RuleNode(10, [RuleNode(3), Hole(get_domain(g₁, :Real))]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:9))
        @test domain == Vector(2:9)
    end

    @testset "Propagating forbidden" begin
        constraint = Forbidden([10, 1])
        context = GrammarContext(RuleNode(10, [RuleNode(3), Hole(get_domain(g₁, :Real))]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:9))
        @test domain == Vector(2:9)
    end

    @testset "Propagating forbidden_tree without variables" begin
        constraint = ForbiddenTree(
            ConstraintMatchNode(10, [ConstraintMatchNode(1), ConstraintMatchNode(1)])
        )
        context = GrammarContext(RuleNode(10, [RuleNode(1), Hole(get_domain(g₁, :Real))]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:9))
        @test domain == Vector(2:9)
    end

    @testset "Propagating forbidden_tree with one variable" begin
        constraint = ForbiddenTree(
            ConstraintMatchNode(10, [ConstraintMatchNode(1), ConstraintMatchVar(:x)])
        )
        context = GrammarContext(RuleNode(10, [RuleNode(1), Hole(get_domain(g₁, :Real))]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:9))
        @test domain == []
    end

    @testset "Propagating forbidden_tree with two variables" begin
        constraint = ForbiddenTree(
            ConstraintMatchNode(10, [ConstraintMatchVar(:x), ConstraintMatchVar(:x)])
        )
        context = GrammarContext(RuleNode(10, [RuleNode(1), Hole(get_domain(g₁, :Real))]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:9))
        @test domain == Vector(2:9)

        context = GrammarContext(RuleNode(10, [RuleNode(5), Hole(get_domain(g₁, :Real))]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:9))
        @test domain == append!(Vector(1:4), Vector(6:9))
    end

    @testset "Propagating forbidden_tree with tree assigned to variables" begin
        constraint = ForbiddenTree(
            ConstraintMatchNode(10, [ConstraintMatchVar(:x), ConstraintMatchVar(:x)])
        )
        expr = RuleNode(10, [RuleNode(10, [RuleNode(2), RuleNode(1)]), RuleNode(10, [RuleNode(2), Hole(Herb.HerbGrammar.get_domain(g₁, :Real))])])
        context=Herb.HerbGrammar.GrammarContext(expr, [2, 2])
        domain = propagate(constraint, g₁, context, [1,2,3])
        @test domain == [3]
    end


end