using HerbCore
using HerbGrammar

#TODO: check if the information in a softfail is correct. for now, the information in softfails is ignored.

@testset verbose=true "PatternMatch" begin

    g = @csgrammar begin
        Real = 1
        Real = :x
        Real = -Real
        Real = Real + Real
        Real = Real * Real
        Real = Real / Real
    end

    @testset "PatternMatchSuccess, no holes" begin
        rn = RuleNode(4, [RuleNode(1), RuleNode(1)])
        mn = MatchNode(4, [MatchNode(1), MatchNode(1)])
        @test pattern_match(rn, mn) isa HerbConstraints.PatternMatchSuccess
    end
    
    @testset "PatternMatchSuccessWhenHoleAssignedTo, 1 hole with a valid domain" begin
        rn_variable_shaped_hole = RuleNode(4, [RuleNode(1), Hole(BitVector((1, 1, 1, 1, 1, 1)))])
        rn_fixed_shaped_hole = RuleNode(4, [RuleNode(1), Hole(BitVector((1, 1, 0, 0, 0, 0)))])
        rn_single_value_hole = RuleNode(4, [RuleNode(1), Hole(BitVector((1, 0, 0, 0, 0, 0)))])
        mn = MatchNode(4, [MatchNode(1), MatchNode(1)])
        @test pattern_match(rn_variable_shaped_hole, mn) isa HerbConstraints.PatternMatchSuccessWhenHoleAssignedTo
        @test pattern_match(rn_fixed_shaped_hole, mn) isa HerbConstraints.PatternMatchSuccessWhenHoleAssignedTo
        @test pattern_match(rn_single_value_hole, mn) isa HerbConstraints.PatternMatchSuccessWhenHoleAssignedTo
        result = pattern_match(rn_fixed_shaped_hole, mn)
        @test result.ind == 1
    end

    @testset "PatternMatchSuccessWhenHoleAssignedTo, 1 fixed shaped hole with children" begin
        rn = FixedShapedHole(BitVector((0, 0, 0, 1, 1, 1)), [RuleNode(1), RuleNode(1)])
        mn = MatchNode(4, [MatchNode(1), MatchNode(1)])
        @test pattern_match(rn, mn) isa HerbConstraints.PatternMatchSuccessWhenHoleAssignedTo
        result = pattern_match(rn, mn)
        @test result.ind == 4
    end

    @testset "PatternMatchHardFail, same shape, no holes" begin
        rn = RuleNode(4, [RuleNode(1), RuleNode(1)])
        mn1 = MatchNode(4, [MatchNode(2), MatchNode(1)])
        mn2 = MatchNode(4, [MatchNode(1), MatchNode(2)])
        mn3 = MatchNode(4, [MatchNode(2), MatchNode(2)])
        @test pattern_match(rn, mn1) isa HerbConstraints.PatternMatchHardFail
        @test pattern_match(rn, mn2) isa HerbConstraints.PatternMatchHardFail
        @test pattern_match(rn, mn3) isa HerbConstraints.PatternMatchHardFail
    end

    @testset "PatternMatchHardFail, different shapes, no holes" begin
        rn = RuleNode(4, [RuleNode(1), RuleNode(1)])
        mn_small = MatchNode(1)
        mn_large = MatchNode(4, [
            MatchNode(1), 
            MatchNode(4, [
                MatchNode(1), 
                MatchNode(1)
            ])
        ])
        @test pattern_match(rn, mn_small) isa HerbConstraints.PatternMatchHardFail
        @test pattern_match(rn, mn_large) isa HerbConstraints.PatternMatchHardFail
    end

    @testset "PatternMatchHardFail, 1 hole with an invalid domain" begin
        rn_variable_shaped_hole = RuleNode(4, [RuleNode(1), Hole(BitVector((0, 1, 1, 1, 1, 1)))])
        rn_fixed_shaped_hole = RuleNode(4, [RuleNode(1), Hole(BitVector((0, 0, 0, 1, 1, 1)))])
        rn_single_value_hole = RuleNode(4, [RuleNode(1), Hole(BitVector((0, 0, 0, 0, 1, 1)))])
        mn = MatchNode(4, [MatchNode(1), MatchNode(1)])
        @test pattern_match(rn_variable_shaped_hole, mn) isa HerbConstraints.PatternMatchHardFail
        @test pattern_match(rn_fixed_shaped_hole, mn) isa HerbConstraints.PatternMatchHardFail
        @test pattern_match(rn_single_value_hole, mn) isa HerbConstraints.PatternMatchHardFail
    end

    @testset "PatternMatchHardFail, 1 hole with a valid domain, 1 hole with an invalid domain" begin
        rn1 = RuleNode(4, [Hole(BitVector((1, 1, 1, 1, 1, 1))), Hole(BitVector((0, 1, 1, 1, 1, 1)))])
        rn2 = RuleNode(4, [Hole(BitVector((0, 1, 1, 1, 1, 1))), Hole(BitVector((1, 1, 1, 1, 1, 1)))])
        mn = MatchNode(4, [MatchNode(1), MatchNode(1)])
        @test pattern_match(rn1, mn) isa HerbConstraints.PatternMatchHardFail
        @test pattern_match(rn2, mn) isa HerbConstraints.PatternMatchHardFail
    end

    @testset "PatternMatchHardFail, 1 fixed shaped hole with an invalid domain" begin
        rn = FixedShapedHole(BitVector((0, 0, 0, 0, 1, 1)), [RuleNode(1), RuleNode(1)])
        mn = MatchNode(4, [MatchNode(1), MatchNode(1)])
        @test pattern_match(rn, mn) isa HerbConstraints.PatternMatchHardFail
    end

    @testset "PatternMatchHardFail, 2 holes with invalid domains" begin
        rn = FixedShapedHole(BitVector((0, 0, 0, 0, 1, 1)), [Hole(BitVector((0, 0, 1, 1, 1, 1))), RuleNode(1)])
        mn = MatchNode(4, [MatchNode(1), MatchNode(1)])
        @test pattern_match(rn, mn) isa HerbConstraints.PatternMatchHardFail
    end

    @testset "PatternMatchHardFail, 1 fixed shaped hole with a valid domain, 1 hole with an invalid domain" begin
        rn = FixedShapedHole(BitVector((0, 0, 0, 1, 1, 1)), [Hole(BitVector((0, 0, 1, 1, 1, 1))), RuleNode(1)])
        mn = MatchNode(4, [MatchNode(1), MatchNode(1)])
        @test pattern_match(rn, mn) isa HerbConstraints.PatternMatchHardFail
    end

    @testset "PatternMatchHardFail, 1 fixed shaped hole with an invalid domain, 1 hole with a valid domain" begin
        rn1 = FixedShapedHole(BitVector((0, 0, 0, 0, 1, 1)), [Hole(BitVector((1, 1, 1, 1, 1, 1))), RuleNode(1)])
        rn2 = FixedShapedHole(BitVector((0, 0, 0, 0, 1, 1)), [RuleNode(1), Hole(BitVector((1, 1, 1, 1, 1, 1)))])
        mn = MatchNode(4, [MatchNode(1), MatchNode(1)])
        @test pattern_match(rn1, mn) isa HerbConstraints.PatternMatchHardFail
        @test pattern_match(rn2, mn) isa HerbConstraints.PatternMatchHardFail
    end

    @testset "PatternMatchHardFail, 2 holes with valid domains, but rule node mismatch" begin
        rn = RuleNode(4, [
            RuleNode(4, [
                Hole(BitVector((1, 1, 1, 1, 1, 1))), 
                Hole(BitVector((1, 1, 1, 1, 1, 1)))
            ]),
            RuleNode(1)
        ])

        mn = MatchNode(4, [
            MatchNode(4, [
                MatchNode(2), 
                MatchNode(2)
            ]),
            MatchNode(2)
        ])

        @test pattern_match(rn, mn) isa HerbConstraints.PatternMatchSoftFail
    end

    @testset "PatternMatchSoftFail, 1 fixed shaped hole with an valid domain, 1 hole with a valid domain" begin
        rn1 = FixedShapedHole(BitVector((0, 0, 0, 1, 1, 1)), [Hole(BitVector((1, 1, 1, 1, 1, 1))), RuleNode(1)])
        rn2 = FixedShapedHole(BitVector((0, 0, 0, 1, 1, 1)), [RuleNode(1), Hole(BitVector((1, 1, 1, 1, 1, 1)))])
        mn = MatchNode(4, [MatchNode(1), MatchNode(1)])
        @test pattern_match(rn1, mn) isa HerbConstraints.PatternMatchSoftFail
        @test pattern_match(rn2, mn) isa HerbConstraints.PatternMatchSoftFail
    end

    @testset "PatternMatchSoftFail, 2 holes with valid domains" begin
        rn = RuleNode(4, [Hole(BitVector((1, 1, 1, 1, 1, 1))), Hole(BitVector((1, 1, 1, 1, 1, 1)))])
        mn = MatchNode(4, [MatchNode(1), MatchNode(1)])
        @test pattern_match(rn, mn) isa HerbConstraints.PatternMatchSoftFail
    end

    @testset "PatternMatchSoftFail, large hole" begin
        rn = RuleNode(4, [RuleNode(1), Hole(BitVector((1, 1, 1, 1, 1, 1)))])
        mn = MatchNode(4, [MatchNode(1), MatchNode(4, [MatchNode(1), MatchNode(1)])])
        @test pattern_match(rn, mn) isa HerbConstraints.PatternMatchSoftFail
    end
end