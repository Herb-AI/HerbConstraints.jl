using HerbCore, HerbGrammar

@testset verbose=true "Tree Manipulations" begin

    function create_dummy_solver()
        grammar = @csgrammar begin
            Number = x | 1
            Number = Number + Number
            Number = Number - Number
        end
        return Solver(grammar, :Number)
    end

    @testset "simplify_hole! VariableShapedHole -> FixedShapedHole" begin
        solver = create_dummy_solver()
        new_state!(solver, VariableShapedHole(BitVector((0, 0, 1, 1))))
        #HerbConstraints.simplify_hole!(solver, Vector{Int}()) this will be done inside `new_state!`
        
        tree = get_tree(solver)
        @test tree isa FixedShapedHole
        @test tree.domain == BitVector((0, 0, 1, 1))
        @test length(tree.children) == 2
        for child ∈ tree.children
            @test child isa VariableShapedHole
            @test child.domain == BitVector((1, 1, 1, 1))
        end
    end

    @testset "simplify_hole! VariableShapedHole -> RuleNode" begin
        solver = create_dummy_solver()
        new_state!(solver, VariableShapedHole(BitVector((0, 0, 0, 1))))
        #HerbConstraints.simplify_hole!(solver, Vector{Int}()) this will be done inside `new_state!`
        
        tree = get_tree(solver)
        @test tree isa RuleNode
        @test tree.ind == 4
        @test length(tree.children) == 2
        for child ∈ tree.children
            @test child isa VariableShapedHole
            @test child.domain == BitVector((1, 1, 1, 1))
        end
    end

    @testset "simplify_hole! FixedShapedHole -> RuleNode" begin
        solver = create_dummy_solver()
        new_state!(solver, FixedShapedHole(BitVector((0, 0, 0, 1)), [RuleNode(1), RuleNode(1)]))
        #HerbConstraints.simplify_hole!(solver, Vector{Int}()) this will be done inside `new_state!`
        
        tree = get_tree(solver)
        @test tree isa RuleNode
        @test tree.ind == 4
        @test length(tree.children) == 2
        for child ∈ tree.children
            @test child isa RuleNode
            @test child.ind == 1
        end
    end

end

