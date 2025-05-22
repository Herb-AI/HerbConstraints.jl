@testset verbose = true "AbstractGrammarConstraint" begin
    @testset "utils" begin
        @testset "_get_new_index" begin
            rule = 8
            mapping = Dict(1 => 10, 2 => 11, 3 => 12)
            @test HerbConstraints._get_new_index(rule, mapping) == 8
            rule = 3
            @test HerbConstraints._get_new_index(rule, mapping) == 12
        end
        # @testset "removeconstraint" begin
        #     grammar = @csgrammar begin
        #         Int = 1
        #         Int = x
        #         Int = -Int
        #         Int = Int + Int
        #         Int = Int * Int
        #     end
        #     # @test isempty(grammar.constraints) == true
        #     c = Contains(2)
        #     addconstraint!(grammar, c)
        #     @test length(grammar.constraints) == 1
        #     @test grammar.constraints[1] == Contains(2)
        #     # # TODO: should there be a get function?
        #     # # TODO: test replacing constraint
        #     # mapping = Dict(1 => 5, 2 => 6, 3 => 1)
        #     # grammar.constraints[1] = Contains(HerbConstraints._get_new_index(c.rule, mapping))
        #     # println(grammar.constraints)
        #     index = findfirst(x -> x == c, grammar.constraints)
        #     println("It's a match! Index: ", index)

        # end
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
