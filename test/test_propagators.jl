
@testset verbose=true "Propagators" begin

    g₁ = @csgrammar begin
        Real = |(1:9)
        Real = Real + Real
        Real = Real * Real
    end

    @testset "Propagating comesafter" begin
        constraint = ComesAfter(1, [9])
        context = GrammarContext(RuleNode(10, [Hole(get_domain(g₁, :Real), true), Hole(get_domain(g₁, :Real))]), [1])
        domain = propagate(constraint, g₁, context, Vector(1:11))
        @test domain == Vector(2:11)
    end

    @testset "Propagating ordered" begin
        constraint = Ordered([2, 1])
        context = GrammarContext(RuleNode(10, [RuleNode(3), Hole(get_domain(g₁, :Real), true)]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:11))
        @test domain == Vector(2:11)
    end

    @testset "Propagating forbidden" begin
        constraint = Forbidden([10, 1])
        context = GrammarContext(RuleNode(10, [RuleNode(3), Hole(get_domain(g₁, :Real), true)]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:11))
        @test domain == Vector(2:11)
    end

    @testset "Propagating forbidden_tree without variables" begin
        constraint = ForbiddenTree(
            MatchNode(10, [MatchNode(1), MatchNode(1)])
        )
        context = GrammarContext(RuleNode(10, [RuleNode(1), Hole(get_domain(g₁, :Real), true)]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:11))
        @test domain == Vector(2:11)
    end

    @testset "Propagating forbidden_tree with one variable" begin
        constraint = ForbiddenTree(
            MatchNode(10, [MatchNode(1), MatchVar(:x)])
        )
        context = GrammarContext(RuleNode(10, [RuleNode(1), Hole(get_domain(g₁, :Real), true)]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:11))
        @test domain == []
    end

    @testset "Propagating forbidden_tree with two variables" begin
        constraint = ForbiddenTree(
            MatchNode(10, [MatchVar(:x), MatchVar(:x)])
        )
        context = GrammarContext(RuleNode(10, [RuleNode(1), Hole(get_domain(g₁, :Real), true)]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:11))
        @test domain == Vector(2:11)

        context = GrammarContext(RuleNode(10, [RuleNode(5), Hole(get_domain(g₁, :Real), true)]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:11))
        @test domain == append!(Vector(1:4), Vector(6:11))
    end

    @testset "Propagating forbidden_tree with tree assigned to variables" begin
        constraint = ForbiddenTree(
            MatchNode(10, [MatchVar(:x), MatchVar(:x)])
        )
        domain = [1,2,3]
        expr = RuleNode(10, [
            RuleNode(10, [
                RuleNode(2), 
                RuleNode(1)
            ]), 
            RuleNode(10, [
                RuleNode(2), 
                Hole(BitArray([i ∈ domain for i ∈ 1:length(g₁.rules)]), true)
            ])
        ])
        context=Herb.HerbGrammar.GrammarContext(expr, [2, 2])
        new_domain = propagate(constraint, g₁, context, domain)
        @test new_domain == [3]
    end


end