@testitem "Forbidden Combination" begin
    using HerbCore, HerbGrammar

    function combination_grammar()
        return @csgrammar begin
            S = 1 | 2 | 3 | 4
            S = f(S, S)
        end
    end

    function two_binary_grammar()
        return @csgrammar begin
            S = 1 | 2
            S = f(S, S) | g(S, S)
        end
    end

    @testset "check_tree keeps child tuples correlated" begin
        # f(1, 2) and f(3, 4) are forbidden combinations
        constraint = ForbiddenCombination(
            RuleNode(5),
            children=[
                AbstractRuleNode[RuleNode(1), RuleNode(2)],
                AbstractRuleNode[RuleNode(3), RuleNode(4)],
            ],
        )
        @test !check_tree(constraint, RuleNode(5, AbstractRuleNode[RuleNode(1), RuleNode(2)]))
        @test !check_tree(constraint, RuleNode(5, AbstractRuleNode[RuleNode(3), RuleNode(4)]))
        @test check_tree(constraint, RuleNode(5, AbstractRuleNode[RuleNode(1), RuleNode(4)]))
        @test check_tree(constraint, RuleNode(5, AbstractRuleNode[RuleNode(3), RuleNode(2)]))
        @test check_tree(constraint, RuleNode(5, AbstractRuleNode[RuleNode(2), RuleNode(1)]))
        @test check_tree(constraint, RuleNode(1))
    end

    @testset "propagation removes every single-hole forbidden tuple" begin
        grammar = combination_grammar()
        # f(1, 2) and f(3, 4) are forbidden combinations
        constraint = ForbiddenCombination(
            RuleNode(5),
            children=[
                AbstractRuleNode[RuleNode(1), RuleNode(2)],
                AbstractRuleNode[RuleNode(3), RuleNode(2)],
            ],
        )
        addconstraint!(grammar, constraint)
        # f({1, 2, 3}, 2) -> collapses to f(2, 2) after propagation
        root = RuleNode(
            5,
            AbstractRuleNode[
                Hole(BitVector([true, true, true, false, false])),
                RuleNode(2),
            ],
        )
        solver = GenericSolver(grammar, root)
        @test isfeasible(solver)
        @test HerbCore.issame(get_children(get_tree(solver))[1], RuleNode(2))
    end

    @testset "propagation removes root only after a child tuple matches" begin
        grammar = two_binary_grammar()
        # f(1, 2) forbidden
        constraint = ForbiddenCombination(
            RuleNode(3),
            children=[AbstractRuleNode[RuleNode(1), RuleNode(2)]],
        )
        addconstraint!(grammar, constraint)
        # {f, g}(1, 2) -> collapses to g(1, 2) after propagation
        matching_root = UniformHole(
            BitVector([false, false, true, true]),
            AbstractRuleNode[RuleNode(1), RuleNode(2)],
        )
        matching_solver = GenericSolver(grammar, matching_root)
        @test isfeasible(matching_solver)
        @test HerbCore.issame(
            get_tree(matching_solver),
            RuleNode(4, AbstractRuleNode[RuleNode(1), RuleNode(2)]),
        )
        # {f, g}(1, 1) -> does not prune
        nonmatching_root = UniformHole(
            BitVector([false, false, true, true]),
            AbstractRuleNode[RuleNode(1), RuleNode(1)],
        )
        nonmatching_solver = GenericSolver(grammar, nonmatching_root)
        nonmatching_tree = get_tree(nonmatching_solver)
        @test isfeasible(nonmatching_solver)
        @test nonmatching_tree isa UniformHole
        @test nonmatching_tree.domain[3]
        @test nonmatching_tree.domain[4]
    end

    @testset "propagation detects exact tuple" begin
        grammar = combination_grammar()
        # f(1, 2) forbidden
        addconstraint!(
            grammar,
            ForbiddenCombination(
                RuleNode(5),
                children=[AbstractRuleNode[RuleNode(1), RuleNode(2)]],
            ),
        )
        # f(1, 2) -> unsat
        solver = GenericSolver(grammar, RuleNode(5, AbstractRuleNode[RuleNode(1), RuleNode(2)]))
        @test !isfeasible(solver)
    end

    @testset "grammar validation and equality" begin
        grammar = combination_grammar()
        # ensure children are not ordered
        c1 = ForbiddenCombination(
            RuleNode(5),
            children=[
                AbstractRuleNode[RuleNode(1), RuleNode(2)],
                AbstractRuleNode[RuleNode(3), RuleNode(4)],
            ],
        )
        c2 = ForbiddenCombination(
            RuleNode(5),
            children=[
                AbstractRuleNode[RuleNode(3), RuleNode(4)],
                AbstractRuleNode[RuleNode(1), RuleNode(2)],
            ],
        )
        @test HerbCore.is_domain_valid(c1, grammar)
        @test HerbGrammar.is_constraint_valid(c1, grammar; allow_empty_children=false)
        @test c1 == c2
    end
end
