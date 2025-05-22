@testset verbose = false "Contains" begin
    contains = Contains(2)

    @testset "check_tree true" begin
        tree1 = RuleNode(2)
        tree2 = RuleNode(2, [
            RuleNode(3, [
                RuleNode(2),
                RuleNode(1)
            ]),
            RuleNode(2)
        ])

        @test check_tree(contains, tree1) == true
        @test check_tree(contains, tree2) == true
    end

    @testset "check_tree false" begin
        tree1 = RuleNode(4)
        tree2 = RuleNode(4, [
            RuleNode(3, [
                RuleNode(4),
                RuleNode(1)
            ]),
            RuleNode(4)
        ])

        @test check_tree(contains, tree1) == false
        @test check_tree(contains, tree2) == false
    end

    @testset "update_rule_indices!" begin
        grammar = @csgrammar begin
            Int = 1
            Int = x
            Int = -Int
            Int = Int + Int
            Int = Int * Int
        end
        addconstraint!(grammar, Contains(2))
        addconstraint!(grammar, Contains(3))
        c = Contains(2)
        n_rules = 5
        mapping = Dict(1 => 5, 2 => 6)
        HerbConstraints.update_rule_indices!(c, grammar.constraints,
            n_rules,
            mapping)
        @test grammar.constraints[1] == Contains(6)
    end
end
