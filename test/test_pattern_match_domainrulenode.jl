using HerbCore
using HerbGrammar

#TODO: check if the information in a softfail is correct. for now, the information in softfails is ignored.

@testset verbose=true "PatternMatch with DomainRuleNode" begin

    #the grammar is not needed in the current implementation
    g = @csgrammar begin
        Real = 1
        Real = 2
        Real = Real - Real
        Real = Real + Real
        Real = Real * Real
        Real = Real / Real
    end

    @testset "PatternMatchSuccess, RuleNode" begin
        node = RuleNode(4, [RuleNode(1), RuleNode(1)])
        drn = DomainRuleNode(BitVector((0, 0, 0, 1, 1, 1)), [RuleNode(1), RuleNode(1)])
        @test pattern_match(node, drn) isa HerbConstraints.PatternMatchSuccess
    end

    @testset "PatternMatchSuccess, RuleNode, multiple DomainRuleNodes" begin
        node = RuleNode(4, [RuleNode(1), RuleNode(1)])
        drn = DomainRuleNode(BitVector((0, 0, 0, 1, 1, 1)), [DomainRuleNode(BitVector((1, 1, 0, 0, 0, 0)), []), DomainRuleNode(BitVector((1, 1, 0, 0, 0, 0)), [])])
        @test pattern_match(node, drn) isa HerbConstraints.PatternMatchSuccess
    end

    @testset "PatternMatchSuccess, FixedShapedHole subsets" begin
        # The FixedShapedHoles match the DomainRuleNode, regardless of how they are filled
        hole1 = FixedShapedHole(BitVector((0, 0, 0, 1, 0, 0)), [RuleNode(1), RuleNode(1)])
        hole2 = FixedShapedHole(BitVector((0, 0, 0, 1, 1, 0)), [RuleNode(1), RuleNode(1)])
        hole3 = FixedShapedHole(BitVector((0, 0, 0, 1, 1, 1)), [RuleNode(1), RuleNode(1)])
        drn = DomainRuleNode(BitVector((0, 0, 0, 1, 1, 1)), [RuleNode(1), RuleNode(1)])
        @test pattern_match(hole1, drn) isa HerbConstraints.PatternMatchSuccess
        @test pattern_match(hole2, drn) isa HerbConstraints.PatternMatchSuccess
        @test pattern_match(hole3, drn) isa HerbConstraints.PatternMatchSuccess
    end

    @testset "PatternMatchSuccess, FixedShapedHole subsets, but children fail" begin
        # The root FixedShapedHole match the DomainRuleNode, but the children do not match
        hole_hardfail = FixedShapedHole(BitVector((0, 0, 0, 1, 1, 0)), [Hole(BitVector((0, 1, 1, 1, 1, 0))), RuleNode(1)])
        hole_successwhen = FixedShapedHole(BitVector((0, 0, 0, 1, 1, 0)), [Hole(BitVector((1, 1, 1, 1, 1, 1))), RuleNode(1)])
        hole_softfail = FixedShapedHole(BitVector((0, 0, 0, 1, 1, 0)), [Hole(BitVector((1, 1, 1, 1, 1, 1))), Hole(BitVector((1, 1, 1, 1, 1, 1)))])
        drn = DomainRuleNode(BitVector((0, 0, 0, 1, 1, 1)), [RuleNode(1), RuleNode(1)])
        @test pattern_match(hole_hardfail, drn) isa HerbConstraints.PatternMatchHardFail
        @test pattern_match(hole_successwhen, drn) isa HerbConstraints.PatternMatchSuccessWhenHoleAssignedTo
        @test pattern_match(hole_softfail, drn) isa HerbConstraints.PatternMatchSoftFail
    end

    @testset "PatternMatchSuccess, with VarNode" begin
        node = RuleNode(4, [RuleNode(1), RuleNode(1)])
        drn = DomainRuleNode(BitVector((0, 0, 0, 1, 1, 1)), [VarNode(:a), VarNode(:a)])
    end

    @testset "PatternMatchSuccessWhenHoleAssignedTo, VariableShapedHole" begin
        # The pattern match is successful when the hole is assigned to one specific value
        hole = VariableShapedHole(BitVector((0, 1, 1, 1, 1, 0)))
        drn = DomainRuleNode(BitVector((1, 1, 0, 0, 0, 0)), [])
        match = pattern_match(hole, drn)
        @test match isa HerbConstraints.PatternMatchSuccessWhenHoleAssignedTo
        @test match.ind == 2

        # The pattern match is successful when the hole is assigned to one of 2 values
        hole = VariableShapedHole(BitVector((1, 1, 1, 1, 1, 0)))
        drn = DomainRuleNode(BitVector((1, 1, 0, 0, 0, 0)), [])
        match = pattern_match(hole, drn)
        @test match isa HerbConstraints.PatternMatchSuccessWhenHoleAssignedTo
        @test length(match.ind) == 2
        @test 1 ∈ match.ind
        @test 2 ∈ match.ind
    end

    @testset "PatternMatchSuccessWhenHoleAssignedTo, terminal FixedShapedHole" begin
        # The pattern match is successful when the hole is assigned to one specific value
        hole = FixedShapedHole(BitVector((0, 1, 1, 0, 0, 0)), [])
        drn = DomainRuleNode(BitVector((1, 1, 0, 0, 0, 0)), [])
        match = pattern_match(hole, drn)
        @test match isa HerbConstraints.PatternMatchSuccessWhenHoleAssignedTo
        @test match.ind == 2

        # The pattern match is successful when the hole is assigned to one of 2 values
        hole = FixedShapedHole(BitVector((1, 1, 1, 0, 0, 0)), [])
        drn = DomainRuleNode(BitVector((1, 1, 0, 0, 0, 0)), [])
        match = pattern_match(hole, drn)
        @test match isa HerbConstraints.PatternMatchSuccessWhenHoleAssignedTo
        @test length(match.ind) == 2
        @test 1 ∈ match.ind
        @test 2 ∈ match.ind
    end

    @testset "PatternMatchSuccessWhenHoleAssignedTo, non-terminal FixedShapedHole" begin
        hole = FixedShapedHole(BitVector((0, 0, 0, 1, 1, 1)), [RuleNode(1), RuleNode(1)])
        drn = DomainRuleNode(BitVector((0, 0, 0, 0, 1, 1)), [RuleNode(1), RuleNode(1)])
        match = pattern_match(hole, drn)
        @test match isa HerbConstraints.PatternMatchSuccessWhenHoleAssignedTo
        @test length(match.ind) == 2
        @test 5 ∈ match.ind
        @test 6 ∈ match.ind
    end

    @testset "PatternMatchHardFail, FixedShapedHole, domains are disjoint" begin
        # at the root
        node = FixedShapedHole(BitVector((0, 0, 1, 1, 0, 0)), [RuleNode(1), RuleNode(1)])
        drn = DomainRuleNode(BitVector((0, 0, 0, 0, 1, 1)), [RuleNode(1), RuleNode(1)])
        @test pattern_match(node, drn) isa HerbConstraints.PatternMatchHardFail

        # at the second child
        node = RuleNode(4, [RuleNode(1), FixedShapedHole(BitVector((1, 1, 0, 0, 0, 0)), [])])
        drn = DomainRuleNode(BitVector((0, 0, 0, 0, 1, 1)), [RuleNode(1), DomainRuleNode(BitVector((0, 0, 1, 1, 0, 0)), [])])
        @test pattern_match(node, drn) isa HerbConstraints.PatternMatchHardFail
    end

    @testset "PatternMatchHardFail, RuleNode" begin
        # at the root
        node = RuleNode(4, [RuleNode(1), RuleNode(1)])
        drn = DomainRuleNode(BitVector((0, 0, 0, 0, 1, 1)), [RuleNode(1), RuleNode(1)])
        @test pattern_match(node, drn) isa HerbConstraints.PatternMatchHardFail

        # at the second child
        node = RuleNode(4, [RuleNode(1), RuleNode(1)])
        drn = DomainRuleNode(BitVector((0, 0, 0, 0, 1, 1)), [RuleNode(1), DomainRuleNode(BitVector((0, 0, 1, 1, 0, 0)), [])])
        @test pattern_match(node, drn) isa HerbConstraints.PatternMatchHardFail
    end

    @testset "PatternMatchHardFail, because of VarNode" begin
        node = RuleNode(4, [RuleNode(1), RuleNode(2)])
        drn = DomainRuleNode(BitVector((0, 0, 0, 1, 1, 1)), [VarNode(:a), VarNode(:a)])
        @test pattern_match(node, drn) isa HerbConstraints.PatternMatchHardFail
    end

    @testset "PatternMatchSoftFail, 2 PatternMatchSuccessWhenHoleAssignedTo" begin
        drn = DomainRuleNode(BitVector((0, 0, 0, 0, 1, 1)), [DomainRuleNode(BitVector((1, 1, 0, 0, 0, 0)), []), DomainRuleNode(BitVector((1, 1, 0, 0, 0, 0)), [])])

        node_roothole = FixedShapedHole(BitVector((0, 0, 0, 1, 1, 1)), [RuleNode(1), RuleNode(1)])
        node_childhole = RuleNode(6, [FixedShapedHole(BitVector((1, 1, 1, 0, 0, 0)), []), RuleNode(1)])
        node_2holes = FixedShapedHole(BitVector((0, 0, 0, 1, 1, 1)), [FixedShapedHole(BitVector((1, 1, 1, 0, 0, 0)), []), RuleNode(1)])
        
        match_roothole = pattern_match(node_roothole, drn)
        match_childhole = pattern_match(node_childhole, drn)
        match_2holes = pattern_match(node_2holes, drn)

        @test match_roothole isa HerbConstraints.PatternMatchSuccessWhenHoleAssignedTo
        @test length(match_roothole.ind) == 2
        @test 5 ∈ match_roothole.ind
        @test 6 ∈ match_roothole.ind

        @test match_childhole isa HerbConstraints.PatternMatchSuccessWhenHoleAssignedTo
        @test length(match_childhole.ind) == 2
        @test 1 ∈ match_childhole.ind
        @test 2 ∈ match_childhole.ind

        @test match_2holes isa HerbConstraints.PatternMatchSoftFail
    end

    @testset "PatternMatchSoftFail, VariableShapedHole, non-terminal DomainRuleNode" begin
        hole = VariableShapedHole(BitVector((0, 0, 0, 0, 1, 1)))
        drn = DomainRuleNode(BitVector((0, 0, 0, 0, 1, 1)), [RuleNode(1), RuleNode(1)])
        @test pattern_match(hole, drn) isa HerbConstraints.PatternMatchSoftFail
    end
end