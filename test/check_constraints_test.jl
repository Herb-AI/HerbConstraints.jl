@testitem "Adding constraints" begin
    using HerbGrammar, HerbConstraints, HerbCore
    @testset "too many children" begin
        grammar = @csgrammar begin
            Int = Int + 1
            Int = 0
        end
        t = RuleNode(1, [RuleNode(2), RuleNode(2)])
        @test_throws ErrorException addconstraint!(grammar, Forbidden(t))
    end

    @testset "Incorrect tree" begin
        grammar = @csgrammar begin
            Int = Int +  1
            Int = Zero
            Zero = 0
        end
        tw = RuleNode(1, [RuleNode(3)])
        @test_throws ErrorException addconstraint!(deepcopy(grammar), Forbidden(tw))
        t = RuleNode(1, [RuleNode(2, [RuleNode(3)])])
        @test_nowarn addconstraint!(deepcopy(grammar), Forbidden(t))
    end

    @testset "Incorrect with holes" begin
        grammar = @csgrammar begin
            Exp = Op
            Op = Exp + Exp
            Op = Exp * Exp
            Exp = 0
            Exp = 1
        end
        @show "this test"
        tw = DomainRuleNode(BitVector([1, 1, 1, 0, 0]), [RuleNode(4), RuleNode(4)])
        @test_throws ErrorException addconstraint!(deepcopy(grammar), Forbidden(tw))
        t = DomainRuleNode(BitVector([0, 1, 1, 0, 0]), [RuleNode(4), RuleNode(4)])
        @test_nowarn addconstraint!(deepcopy(grammar), Forbidden(t))
    end

    @testset "No errors" begin
        grammar = @cfgrammar begin
            Number = |(1:2)
            Number = x
            Number = Number + Number
            Number = Number * Number
        end
        tree1 = UniformHole(BitVector((0, 0, 0, 1, 1)), [RuleNode(2), RuleNode(4, [VarNode(:a), VarNode(:b)])])
        ContainsSubtree(tree1)

        @test_nowarn addconstraint!(grammar, ContainsSubtree(tree1))
    end

    @testset "DRN with different types" begin
        grammar = @csgrammar begin
            M = E - E
            P = E + E
            Mul = C * C
            E = P
            E = M
            E = C
            C = 0
        end 
        tree = DomainRuleNode(BitVector((1, 1, 1, 0, 0, 0, 0)), [VarNode(:a), VarNode(:a)])
        @test_nowarn addconstraint!(grammar, Forbidden(tree))
    end

    @testset "Forbidden constraints" begin
        grammar = @csgrammar begin
            S = A
            A = C
            B = D
            C = 1
        end
        @test_nowarn addconstraint!(grammar, ForbiddenSequence([1, 2]))
        @test_throws ErrorException addconstraint!(grammar, ForbiddenSequence([1, 3]))
        @test_nowarn addconstraint!(grammar, ForbiddenSequence([1, 4]))
    end

    @testset "UniformHoles" begin
        g = @csgrammar begin
            Real = 1
            Real = 2
            Real = x
            Real = Real + Real
            Real = Real * Real
        end
        t = UniformHole(BitVector((0, 0, 0, 1, 0)), [RuleNode(4), RuleNode(5)])
        c = ContainsSubtree(t)
        @test_nowarn addconstraint!(g, c; allow_empty_children=true)
        @test_throws ErrorException addconstraint!(g, c)
    end

end