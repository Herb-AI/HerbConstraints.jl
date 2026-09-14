@testitem "check_tree true" tags = [:Forbidden, :check_tree] begin
    using HerbCore
    tree = RuleNode(4, [
        VarNode(:a),
        VarNode(:a)
    ])

    forbidden = Forbidden(tree)

    tree12 = RuleNode(4, [
        RuleNode(1),
        RuleNode(2)
    ])
    tree21 = RuleNode(4, [
        RuleNode(2),
        RuleNode(1)
    ])
    tree22_mismatchedroot = RuleNode(3, [
        RuleNode(2),
        RuleNode(2)
    ])
    tree_large_true = RuleNode(3, [
        RuleNode(4, [
            RuleNode(2),
            RuleNode(3, [
                RuleNode(2),
                RuleNode(2)
            ])
        ]),
        RuleNode(2)
    ])
    @test check_tree(forbidden, tree12) == true
    @test check_tree(LocalForbidden([], tree), tree12) == true
    @test check_tree(forbidden, tree21) == true
    @test check_tree(LocalForbidden([], tree), tree21) == true
    @test check_tree(forbidden, tree22_mismatchedroot) == true
    @test check_tree(LocalForbidden([], tree), tree22_mismatchedroot) == true
    @test check_tree(forbidden, tree_large_true) == true
    @test check_tree(LocalForbidden([], tree), tree_large_true) == true
end

@testitem "check_tree false" tags = [:Forbidden, :check_tree] begin
    using HerbCore
    tree = RuleNode(4, [
        VarNode(:a),
        VarNode(:a)
    ])
    forbidden = Forbidden(tree)

    tree11 = RuleNode(4, [
        RuleNode(1),
        RuleNode(1)
    ])
    tree22 = RuleNode(4, [
        RuleNode(2),
        RuleNode(2)
    ])
    tree_large_false = RuleNode(3, [
        RuleNode(4, [
            RuleNode(3, [
                RuleNode(2),
                RuleNode(2)
            ]),
            RuleNode(3, [
                RuleNode(2),
                RuleNode(2)
            ])
        ]),
        RuleNode(2)
    ])
    @test check_tree(forbidden, tree11) == false
    @test check_tree(LocalForbidden([], tree), tree11) == false
    @test check_tree(forbidden, tree22) == false
    @test check_tree(LocalForbidden([], tree), tree22) == false
    @test check_tree(forbidden, tree_large_false) == false
    @test check_tree(LocalForbidden([1], tree), tree_large_false) == false
end

@testitem "Forbidden" begin
    using HerbCore, HerbGrammar

    forbidden = Forbidden(RuleNode(4, [
        VarNode(:a),
        VarNode(:a)
    ]))


    @testset "update_rule_indices" begin
        @testset "interface without grammar" begin
            forbidden = Forbidden(RuleNode(3, [VarNode(:a), VarNode(:a)
            ]))
            tree = @rulenode 3{4{2,3{2,2}},7}
            n_rules = 5
            HerbCore.update_rule_indices!(forbidden, n_rules)
            @test check_tree(forbidden, tree) == false
            @test forbidden.tree == RuleNode(3, [VarNode(:a), VarNode(:a)
            ])

            mapping = Dict(3 => 9, 2 => 22)
            constraints = [forbidden]
            expected_forbidden = Forbidden(RuleNode(9, [VarNode(:a), VarNode(:a)
            ]))
            HerbCore.update_rule_indices!(forbidden, n_rules, mapping, constraints)
            @test check_tree(forbidden, tree) == true
            @test forbidden.tree == expected_forbidden.tree
        end
        @testset "interface with grammar" begin
            grammar = @csgrammar begin
                Int = |(1:9)
                Int = x
                Int = -Int
                Int = Int + Int
                Int = Int * Int
            end
            forbidden = Forbidden(RuleNode(12, [VarNode(:a), VarNode(:a)]))
            addconstraint!(grammar, forbidden)
            tree = @rulenode 12{13{2,12{2,2}},7}
            HerbCore.update_rule_indices!(forbidden, grammar)
            @test check_tree(forbidden, tree) == false
            @test forbidden.tree == RuleNode(12, [VarNode(:a), VarNode(:a)])

            mapping = Dict(12 => 9, 2 => 22)
            expected_forbidden = Forbidden(RuleNode(9, [VarNode(:a), VarNode(:a)
            ]))
            HerbCore.update_rule_indices!(forbidden, grammar, mapping)
            @test check_tree(forbidden, tree) == true
            @test forbidden.tree == expected_forbidden.tree
        end
    end
    @testset "is_domain_valid" begin
        grammar = @csgrammar begin
            Int = 1
            Int = x
            Int = -Int
            Int = Int + Int
            Int = Int * Int
        end
        forbidden1 = Forbidden(RuleNode(3, [RuleNode(5), RuleNode(8)]))
        forbidden2 = Forbidden(RuleNode(3, [VarNode(:a), VarNode(:a)]))
        @test HerbCore.is_domain_valid(forbidden1, grammar) == false
        @test HerbCore.is_domain_valid(forbidden2, grammar) == true
    end
    @testset "isequal" begin
        forbidden1 = Forbidden(RuleNode(4, [
            VarNode(:a),
            VarNode(:a)
        ]))
        forbidden2 = Forbidden(RuleNode(4, [
            VarNode(:a),
            VarNode(:a)
        ]))
        forbidden3 = Forbidden(RuleNode(4, [
            VarNode(:b),
            VarNode(:b)
        ]))
        @test forbidden1 == forbidden2
        @test forbidden1 != forbidden3
    end
end
