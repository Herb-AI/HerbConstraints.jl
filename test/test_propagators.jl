
@testset verbose=true "Propagators" begin

    g₁ = @csgrammar begin
        Real = |(1:5)
        Real = 6 | 7 | 8
        Real = Real + Real
        Real = Real * Real
    end

    @testset "Propagating comesafter" begin
        constraint = ComesAfter(1, [9])
        context = GrammarContext(RuleNode(10), [1])
        domain = propagate(constraint, g₁, context, Vector(1:9))
        @test domain == Vector(2:9)
    end

    @testset "Propagating ordered" begin
        constraint = Ordered([2, 1])
        context = GrammarContext(RuleNode(10, [RuleNode(3)]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:9))
        @test domain == Vector(2:9)
    end

    @testset "Propagating forbidden" begin
        constraint = Forbidden([10, 1])
        context = GrammarContext(RuleNode(10, [RuleNode(3)]), [2])
        domain = propagate(constraint, g₁, context, Vector(1:9))
        @test domain == Vector(2:9)
    end

end