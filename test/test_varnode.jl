@testset verbose=false "VarNode" begin

    @testset "number_of_varnodes" begin
        @test HerbConstraints.contains_varnode(RuleNode(1), :a) == false
        @test HerbConstraints.contains_varnode(VarNode(:a), :a) == true
        @test HerbConstraints.contains_varnode(VarNode(:b), :a) == false
        @test HerbConstraints.contains_varnode(RuleNode(2, [
            VarNode(:b),
            VarNode(:a)
        ]), :a) == true
        @test HerbConstraints.contains_varnode(RuleNode(2, [
            VarNode(:b),
            VarNode(:b)
        ]), :a) == false
    end
end
