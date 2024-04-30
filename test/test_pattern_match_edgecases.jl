using HerbCore
using HerbGrammar

#These test contain edgecases that fail in the current implemention
@testset verbose=false "PatternMatch Edgecase" begin

    #the grammar is not needed in the current implementation
    g = @csgrammar begin
        Real = 1
        Real = :x
        Real = -Real
        Real = Real + Real
        Real = Real * Real
        Real = Real / Real
    end

    @testset "3 VarNodes: pairwise Softfail, triplewise HardFail" begin
        #TODO: this test fails because, in the current implementation, variable comparisons are done pairwise
        # domains of holes within vars should be updated for stronger inference
        rn = RuleNode(4, [
            RuleNode(4, [Hole(BitVector((1, 1, 0))), Hole(BitVector((0, 1, 1)))]), 
            Hole(BitVector((1, 0, 1)))
        ])
        mn = RuleNode(4, [
            RuleNode(4, [VarNode(:x), VarNode(:x)]),
            VarNode(:x)
        ])
        @test pattern_match(rn, mn) isa HerbConstraints.PatternMatchHardFail
    end

    @testset "3 VarNodes: HardFail on instance 2 and 3" begin
        #TODO: this test fails because, in the current implementation, only (1, 2) and (1, 3) are compared
        # domains of holes within vars should be updated for stronger inference
        rn = RuleNode(4, [
            RuleNode(4, [Hole(BitVector((1, 1, 1))), RuleNode(1)]), 
            RuleNode(2)
        ])
        mn = RuleNode(4, [
            RuleNode(4, [VarNode(:x), VarNode(:x)]),
            VarNode(:x)
        ])
        @test pattern_match(rn, mn) isa HerbConstraints.PatternMatchHardFail
    end
end
