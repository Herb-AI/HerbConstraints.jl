@testset verbose = true "AbstractGrammarConstraint" begin
    @testset "add_rule! to grammar and update constraints" begin
        # define grammar
        grammar = @cfgrammar begin
            Number = |(1:2)
            Number = x
            Number = Number + Number
            Number = Number * Number
        end

        # add constraints
        contains = Contains(3)
        forbidden_sequence = ForbiddenSequence([1, 2, 3])
        tree1 = UniformHole(BitVector((0, 0, 1, 1, 0)), [RuleNode(2), RuleNode(4, [UniformHole(BitVector((1, 1, 0, 0, 0)), []), UniformHole(BitVector((1, 1, 0, 0, 0)), [])])])
        tree2 = RuleNode(4, [VarNode(:a), RuleNode(1)])
        contains_subtree = ContainsSubtree(tree1)
        forbidden = Forbidden(tree2)

        addconstraint!(grammar, contains)
        addconstraint!(grammar, forbidden_sequence)
        addconstraint!(grammar, contains_subtree)
        addconstraint!(grammar, forbidden)

        # add more rules to grammar
        add_rule!(grammar, :(Number = 3 | 4))
        @test length(grammar.rules) == 7

        expected_bv1 = BitVector((0, 0, 1, 1, 0, 0, 0))
        expected_bv2 = BitVector((1, 1, 0, 0, 0, 0, 0))
        expected_bv3 = BitVector((1, 1, 0, 0, 0, 0, 0))

        @test grammar.constraints[1] == Contains(3) # no changes
        @test grammar.constraints[2].sequence == [1, 2, 3] # no changes
        @test grammar.constraints[3].tree.domain == expected_bv1# size BV changes
        @test grammar.constraints[3].tree.children[2].children[1].domain == expected_bv2
        @test grammar.constraints[3].tree.children[2].children[2].domain == expected_bv3
        @test grammar.constraints[4].tree == tree2 # no changes
    end
    @testset "merge_grammars! and update constraints" begin
        @testset "Simple example" begin
            merge_to = @csgrammar begin
                Real = |(1:2)
                Real = x
            end
            merge_from = @csgrammar begin
                Real = Real + Real
                Real = Real * Real
            end
            # TODO: update tests to make sense with addconstraint! that checks if domain is valid
            ordered_operations_constraint = Ordered(DomainRuleNode([1, 1], [VarNode(:v), VarNode(:w)]), [:v, :w])
            tree = UniformHole(BitVector((0, 0, 1, 1, 0)), [RuleNode(1), RuleNode(2)])
            contains_subtree_constraint = ContainsSubtree(tree)
            addconstraint!(merge_from, ordered_operations_constraint)
            addconstraint!(merge_from, contains_subtree_constraint)
            # merge_grammars!(merge_to, merge_from)

            # @test merge_to.constraints[1].tree.domain == BitVector((0, 0, 0, 1, 1))
            # @test merge_to.constraints[2].tree.children == [RuleNode(4), RuleNode(5)]
        end
        @testset "Duplicate rules" begin
            merge_to = @csgrammar begin
                Int = Int + Int
                Int = x | 1 | 2 | 3
            end
            addconstraint!(merge_to, Contains(1))

            merge_from = @csgrammar begin
                Int = x | 1 | 2 | 3
                Int = Int + Int
            end
            addconstraint!(merge_from, Contains(5))
            addconstraint!(merge_from, Contains(3))

            merge_grammars!(merge_to, merge_from)
            # Note: addconstraint! (used in merge_grammars!) currently does not check for duplicate constraints. 
            # Might change in the future and some of the tests will need to be updated.
            @test length(merge_to.constraints) == 3
            @test Contains(1) in merge_to.constraints
            @test Contains(4) in merge_to.constraints
        end
    end
    @testset "addconstraint!" begin
        grammar = @cfgrammar begin
            Number = |(1:2)
            Number = x
            Number = Number + Number
            Number = Number * Number
        end
        # valid domains
        @test isempty(grammar.constraints) == true
        # invalid domains
    end
end
