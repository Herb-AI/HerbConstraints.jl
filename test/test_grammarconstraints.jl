@testset verbose = true "AbstractGrammarConstraint" begin
    @testset "utils" begin
        @testset "_get_new_index" begin
            rule = 8
            mapping = Dict(1 => 10, 2 => 11, 3 => 12)
            @test HerbConstraints._get_new_index(rule, mapping) == 8
            rule = 3
            @test HerbConstraints._get_new_index(rule, mapping) == 12
        end
    end
    @testset "error" begin
        struct TestConstraintWithoutImpl <: AbstractGrammarConstraint end
        n_rules = 5
        c = TestConstraintWithoutImpl()
        @test_throws ErrorException HerbCore.update_rule_indices!(c, n_rules)
        mapping = Dict(1 => 5, 2 => 6, 3 => 1)
        constraints = [c]
        @test_throws ErrorException HerbCore.update_rule_indices!(
            c, n_rules, mapping, constraints)
    end
    @testset "Add rules to grammar and update constraints" begin
        # define grammar
        grammar = @cfgrammar begin
            Number = |(1:2)
            Number = x
            Number = Number + Number
            Number = Number * Number
        end

        # add constraints
        contains = Contains(3)
        forbidden_sequence = ForbiddenSequence([1, 2, 3])
        tree1 = UniformHole(BitVector((0, 0, 1, 1, 0)), [RuleNode(2), RuleNode(4, [UniformHole(BitVector((1, 1, 0, 0, 0)), []), UniformHole(BitVector((1, 1, 0, 0, 0)), [])])])
        tree2 = RuleNode(4, [VarNode(:a), RuleNode(1)])
        contains_subtree = ContainsSubtree(tree1)
        forbidden = Forbidden(tree2)

        addconstraint!(grammar, contains)
        addconstraint!(grammar, forbidden_sequence)
        addconstraint!(grammar, contains_subtree)
        addconstraint!(grammar, forbidden)

        # add more rules to grammar
        add_rule!(grammar, :(Number = 3 | 4))
        @test length(grammar.rules) == 7

        # TODO: check if constraints were updated as expected
        expected_contains_subtree = ContainsSubtree(UniformHole(BitVector((0, 0, 1, 1, 0, 0, 0)), [RuleNode(2), RuleNode(4, [UniformHole(BitVector((1, 1, 0, 0, 0, 0, 0)), []), UniformHole(BitVector((1, 1, 0, 0, 0, 0, 0)), [])])]))
        expected_forbidden = Forbidden(tree2)

        @test grammar.constraints[1] == Contains(3) # no changes
        @test grammar.constraints[2].sequence == [1, 2, 3] # no changes
        @test grammar.constraints[3] == expected_contains_subtree # size BV changes
        @test grammar.constraints[4] == expected_forbidden # no changes
    end
end
