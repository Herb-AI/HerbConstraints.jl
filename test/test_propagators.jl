using HerbGrammar
@testset verbose=true "Propagators" begin

    g₁ = @csgrammar begin
        Real = |(1:9)
        Real = Real + Real
        Real = Real * Real
    end

    @testset "Propagating comesafter" begin
        constraint = ComesAfter(1, [9])
        context = GrammarContext(RuleNode(10, [Hole(get_domain(g₁, :Real)), Hole(get_domain(g₁, :Real))]), [1], Set{Int}())
        domain, _ = propagate(constraint, g₁, context, Vector(1:9), nothing)
        @test domain == Vector(2:9)
    end

    @testset "Propagating require on left" begin
        constraint = RequireOnLeft([2, 1])
        context = GrammarContext(RuleNode(10, [RuleNode(3), Hole(get_domain(g₁, :Real))]), [2], Set{Int}())
        domain, _ = propagate(constraint, g₁, context, Vector(1:9), nothing)
        @test domain == Vector(2:9)        
    end

    @testset "Propagating require on left 2" begin
        constraint = RequireOnLeft([2, 1])
        context = GrammarContext(RuleNode(10, [RuleNode(2), Hole(get_domain(g₁, :Real))]), [2], Set{Int}())
        domain, _ = propagate(constraint, g₁, context, Vector(1:9), nothing)
        @test domain == Vector(1:9)
    end

    @testset "Propagating forbidden path" begin
        constraint = ForbiddenPath([10, 1])
        context = GrammarContext(RuleNode(10, [RuleNode(3), Hole(get_domain(g₁, :Real))]), [2], Set{Int}())
        domain, _ = propagate(constraint, g₁, context, Vector(1:9), nothing)
        @test domain == Vector(2:9)
    end

    @testset "Propagating LocalForbidden without variables" begin
        constraint = LocalForbidden(
            [],
            MatchNode(10, [MatchNode(1), MatchNode(1)])
        )
        context = GrammarContext(RuleNode(10, [RuleNode(1), Hole(get_domain(g₁, :Real))]), [2], Set{Int}())
        domain, _ = propagate(constraint, g₁, context, Vector(1:9), nothing)
        @test domain == Vector(2:9)
    end

    @testset "Propagating LocalForbidden with one variable" begin
        constraint = LocalForbidden(
            [],
            MatchNode(10, [MatchNode(1), MatchVar(:x)])
        )
        context = GrammarContext(RuleNode(10, [RuleNode(1), Hole(get_domain(g₁, :Real))]), [2], Set{Int}())
        domain, _ = propagate(constraint, g₁, context, Vector(1:9), nothing)
        @test domain == []
    end

    @testset "Propagating LocalForbidden with two variables" begin
        constraint = LocalForbidden(
            [],
            MatchNode(10, [MatchVar(:x), MatchVar(:x)])
        )
        context = GrammarContext(RuleNode(10, [RuleNode(1), Hole(get_domain(g₁, :Real))]), [2], Set{Int}())
        domain, _ = propagate(constraint, g₁, context, Vector(1:9), nothing)
        @test domain == Vector(2:9)

        context = GrammarContext(RuleNode(10, [RuleNode(5), Hole(get_domain(g₁, :Real))]), [2], Set{Int}())
        domain, _ = propagate(constraint, g₁, context, Vector(1:9), nothing)
        @test domain == append!(Vector(1:4), Vector(6:9))
    end

    @testset "Propagating LocalForbidden with tree assigned to variables" begin
        constraint₁ = LocalForbidden(
            [],
            MatchNode(10, [MatchVar(:x), MatchVar(:x)])
        )
        constraint₂ = LocalForbidden(
            [2],
            MatchNode(10, [MatchVar(:x), MatchVar(:x)])
        )
        expr = RuleNode(10, [RuleNode(10, [RuleNode(2), RuleNode(1)]), RuleNode(10, [RuleNode(2), Hole(get_domain(g₁, :Real))])])
        context = GrammarContext(expr, [2, 2], Set{Int}())
        domain, _ = propagate(constraint₁, g₁, context, [1,2,3], nothing)
        domain, _ = propagate(constraint₂, g₁, context, domain, nothing)
        @test domain == [3]
    end

    @testset "Propagating LocalOrdered with lower bound" begin
        constraint₁ = LocalOrdered(
            [],
            MatchNode(10, [MatchVar(:x), MatchVar(:y)]),
            [:x, :y]
        )

        expr = RuleNode(10, [RuleNode(8), Hole(get_domain(g₁, :Real))])
        context = GrammarContext(expr, [2], Set{Int}())
        domain, _ = propagate(constraint₁, g₁, context, collect(1:9), nothing)
        @test domain == [8, 9]
    end

    @testset "Propagating LocalOrdered with trees" begin
        expr = RuleNode(10, [
            RuleNode(10, [
                RuleNode(1),
                RuleNode(1)
            ]),
            RuleNode(10, [
                RuleNode(1),
                Hole(get_domain(g₁, :Real))
            ])
        ])
        context = GrammarContext(expr, [2, 2], Set{Int}())
        
        constraint = LocalOrdered(
            [], 
            MatchNode(10, [MatchVar(:x₁), MatchVar(:x₂)]),
            [:x₂, :x₁]
        )
        
        domain, _ = propagate(constraint, g₁, context, [1,2,3], nothing)
        
        @test domain == [1]
    end

end