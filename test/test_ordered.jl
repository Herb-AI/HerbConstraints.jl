@testset verbose=false "Ordered" begin
    @testset "check_tree true, length(order)=2" begin
        ordered = Ordered(RuleNode(4, [
            VarNode(:a),
            VarNode(:b)
        ]), [:a, :b])
        tree11 = RuleNode(4, [
            RuleNode(1),
            RuleNode(1)
        ])
        tree12 = RuleNode(4, [
            RuleNode(1),
            RuleNode(2)
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
        @test check_tree(ordered, tree11) == true
        @test check_tree(ordered, tree12) == true
        @test check_tree(ordered, tree22) == true
        @test check_tree(ordered, tree22_mismatchedroot) == true
        @test check_tree(ordered, tree_large_true) == true
    end

    @testset "check_tree false, length(order)=2" begin
        ordered = Ordered(RuleNode(4, [
            VarNode(:a),
            VarNode(:b)
        ]), [:a, :b])
        tree21 = RuleNode(4, [
            RuleNode(2),
            RuleNode(1)
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
        @test check_tree(ordered, tree21) == false
        @test check_tree(ordered, tree_large_false) == false
    end

    @testset "check_tree true, length(order)=3" begin
        ordered = Ordered(RuleNode(4, [
            VarNode(:a),
            VarNode(:b),
            VarNode(:c)
        ]), [:a, :b, :c])
        tree111 = RuleNode(4, [
            RuleNode(1),
            RuleNode(1),
            RuleNode(1)
        ])
        tree112 = RuleNode(4, [
            RuleNode(1),
            RuleNode(1),
            RuleNode(2)
        ])
        tree122 = RuleNode(4, [
            RuleNode(1),
            RuleNode(2),
            RuleNode(2)
        ])
        tree111_mismatchedroot = RuleNode(5, [
            RuleNode(1),
            RuleNode(1),
            RuleNode(1)
        ])
        tree123 = RuleNode(4, [
            RuleNode(1),
            RuleNode(2),
            RuleNode(3, [
                RuleNode(1),
                RuleNode(1),
            ])
        ])
        tree133 = RuleNode(4, [
            RuleNode(1),
            RuleNode(3, [
                RuleNode(1),
                RuleNode(1),
            ]),
            RuleNode(3, [
                RuleNode(1),
                RuleNode(1),
            ])
        ])
        @test check_tree(ordered, tree111) == true
        @test check_tree(ordered, tree112) == true
        @test check_tree(ordered, tree122) == true
        @test check_tree(ordered, tree111_mismatchedroot) == true
        @test check_tree(ordered, tree123) == true
        @test check_tree(ordered, tree133) == true
    end

    @testset "check_tree false, length(order)=3" begin
        ordered = Ordered(RuleNode(4, [
            VarNode(:a),
            VarNode(:b),
            VarNode(:c)
        ]), [:a, :b, :c])
        tree121 = RuleNode(4, [
            RuleNode(1),
            RuleNode(2),
            RuleNode(1)
        ])
        tree133_leftchild_false = RuleNode(4, [
            RuleNode(1),
            RuleNode(3, [
                RuleNode(2),
                RuleNode(1),
            ]),
            RuleNode(3, [
                RuleNode(1),
                RuleNode(1),
            ])
        ])
        tree133_rightchild_false = RuleNode(4, [
            RuleNode(1),
            RuleNode(3, [
                RuleNode(1),
                RuleNode(2),
            ]),
            RuleNode(3, [
                RuleNode(1),
                RuleNode(1),
            ])
        ])
        @test check_tree(ordered, tree121) == false
        @test check_tree(ordered, tree133_leftchild_false) == false
        @test check_tree(ordered, tree133_rightchild_false) == false
    end
end
