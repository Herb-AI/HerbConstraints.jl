using HerbCore, HerbGrammar

@testset verbose=true "Tree Manipulations" begin

    function create_dummy_solver()
        grammar = @csgrammar begin
            Number = x | 1
            Number = Number + Number
            Number = Number - Number
        end
        return GenericSolver(grammar, :Number)
    end

    @testset "simplify_hole! Hole -> UniformHole" begin
        solver = create_dummy_solver()
        new_state!(solver, Hole(BitVector((0, 0, 1, 1))))
        #HerbConstraints.simplify_hole!(solver, Vector{Int}()) this will be done inside `new_state!`
        
        tree = get_tree(solver)
        @test tree isa UniformHole
        @test tree.domain == BitVector((0, 0, 1, 1))
        @test length(tree.children) == 2
        for child ∈ tree.children
            @test child isa Hole
            @test child.domain == BitVector((1, 1, 1, 1))
        end
    end

    @testset "simplify_hole! Hole -> RuleNode" begin
        solver = create_dummy_solver()
        new_state!(solver, Hole(BitVector((0, 0, 0, 1))))
        #HerbConstraints.simplify_hole!(solver, Vector{Int}()) this will be done inside `new_state!`
        
        tree = get_tree(solver)
        @test tree isa RuleNode
        @test tree.ind == 4
        @test length(tree.children) == 2
        for child ∈ tree.children
            @test child isa Hole
            @test child.domain == BitVector((1, 1, 1, 1))
        end
    end

    @testset "simplify_hole! UniformHole -> RuleNode" begin
        solver = create_dummy_solver()
        new_state!(solver, UniformHole(BitVector((0, 0, 0, 1)), [RuleNode(1), RuleNode(1)]))
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

