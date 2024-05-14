@testset verbose=false "Forbidden" begin
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
end
