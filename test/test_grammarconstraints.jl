@testset verbose = true "AbstractGrammarConstraint" begin
    @testset "utils" begin
        rule = 8
        mapping = Dict(1 => 10, 2 => 11, 3 => 12)
        @test HerbConstraints._get_new_index(rule, mapping) == 8
        rule = 3
        @test HerbConstraints._get_new_index(rule, mapping) == 12
    end
    @testset "error" begin
        struct TestConstraintWithoutImpl <: AbstractGrammarConstraint end
        n_rules = 5
        constraint = TestConstraintWithoutImpl()
        @test_throws ErrorException HerbConstraints.update_rule_indices!(constraint, n_rules)
        mapping = Dict(1 => 5, 2 => 6, 3 => 1)
        @test_throws ErrorException HerbConstraints.update_rule_indices!(
            constraint, n_rules, mapping)
    end
end
