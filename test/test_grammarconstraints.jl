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
        @test_throws ErrorException HerbConstraints.update_rule_indices!(c, n_rules)
        mapping = Dict(1 => 5, 2 => 6, 3 => 1)
        constraints = [c]
        @test_throws ErrorException HerbConstraints.update_rule_indices!(
            c, n_rules, mapping, constraints)
    end

end
