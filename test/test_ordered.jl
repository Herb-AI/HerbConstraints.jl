@testset verbose=true "Ordered" begin
    ordered = Ordered(RuleNode(4, [
        VarNode(:a),
        VarNode(:b)
    ]), [:a, :b])

    @testset "check_tree" begin
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
        tree22 = RuleNode(4, [
            RuleNode(2),
            RuleNode(2)
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
        tree_large_false = RuleNode(3, [
            RuleNode(4, [
                RuleNode(3, [
                    RuleNode(2),
                    RuleNode(2)
                ]),
                RuleNode(2)
            ]),
            RuleNode(2)
        ])
        @test check_tree(ordered, tree11) == true
        @test check_tree(ordered, tree12) == true
        @test check_tree(ordered, tree21) == false
        @test check_tree(ordered, tree22) == true
        @test check_tree(ordered, tree22_mismatchedroot) == true
        @test check_tree(ordered, tree_large_true) == true
        @test check_tree(ordered, tree_large_false) == false
    end
end
