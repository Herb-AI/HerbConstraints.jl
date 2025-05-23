@testset verbose = false "Forbidden" begin
    forbidden = Forbidden(RuleNode(4, [
        VarNode(:a),
        VarNode(:a)
    ]))

    @testset "check_tree true" begin
        tree11 = RuleNode(4, [
            RuleNode(1),
            RuleNode(1)
        ])
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
        @test check_tree(forbidden, tree11) == false
        @test check_tree(forbidden, tree12) == true
        @test check_tree(forbidden, tree21) == true
        @test check_tree(forbidden, tree22_mismatchedroot) == true
        @test check_tree(forbidden, tree_large_true) == true
    end

    @testset "check_tree false" begin
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
        @test check_tree(forbidden, tree22) == false
        @test check_tree(forbidden, tree_large_false) == false
    end

    @testset "update_rule_indices" begin
        forbidden = Forbidden(RuleNode(3, [VarNode(:a), VarNode(:a)
        ]))
        tree = @rulenode 3{4{2,3{2,2}},7}
        n_rules = 5
        HerbConstraints.update_rule_indices!(forbidden, n_rules)
        @test check_tree(forbidden, tree) == false
        @test forbidden.tree == RuleNode(3, [VarNode(:a), VarNode(:a)
        ])

        mapping = Dict(3 => 9, 2 => 22)
        constraints = [forbidden]
        expected_forbidden = Forbidden(RuleNode(9, [VarNode(:a), VarNode(:a)
        ]))
        HerbConstraints.update_rule_indices!(forbidden, n_rules, mapping, constraints)
        @test check_tree(forbidden, tree) == true
        @test forbidden.tree == expected_forbidden.tree
    end
end
