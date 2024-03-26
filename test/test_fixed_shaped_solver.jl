@testset verbose=true "FixedShapedSolver" begin

    function create_dummy_grammar_and_tree_128programs()
        grammar = @csgrammar begin
            Number = Number + Number
            Number = Number - Number
            Number = Number * Number
            Number = Number / Number
            Number = x | 1 | 2 | 3
        end

        fixed_shaped_tree = RuleNode(1, [
            FixedShapedHole(BitVector((1, 1, 1, 1, 0, 0, 0, 0)), [
                FixedShapedHole(BitVector((0, 0, 0, 0, 1, 1, 1, 1)), [])
                FixedShapedHole(BitVector((0, 0, 0, 0, 1, 0, 0, 1)), [])
            ]),
            FixedShapedHole(BitVector((0, 0, 0, 0, 1, 1, 1, 1)), [])
        ])
         # 4 * 4 * 2 * 4 = 128 programs without constraints

        return grammar, fixed_shaped_tree
    end

    @testset "Without constraints" begin
        grammar, fixed_shaped_tree = create_dummy_grammar_and_tree_128programs()
        fixed_shaped_solver = FixedShapedSolver(grammar, fixed_shaped_tree)
        @test HerbConstraints.count_solutions(fixed_shaped_solver) == 128
    end

    @testset "Forbidden constraint" begin
        #forbid "a - a"
        grammar, fixed_shaped_tree = create_dummy_grammar_and_tree_128programs()
        addconstraint!(grammar, Forbidden(RuleNode(2, [VarNode(:a), VarNode(:a)])))
        fixed_shaped_solver = FixedShapedSolver(grammar, fixed_shaped_tree)
        @test HerbConstraints.count_solutions(fixed_shaped_solver) == 120

        #forbid all rulenodes
        grammar, fixed_shaped_tree = create_dummy_grammar_and_tree_128programs()
        addconstraint!(grammar, Forbidden(VarNode(:a)))
        fixed_shaped_solver = FixedShapedSolver(grammar, fixed_shaped_tree)
        @test HerbConstraints.count_solutions(fixed_shaped_solver) == 0
    end

    @testset "The root is the only solution" begin
        grammar = @csgrammar begin
            S = 1
        end
        
        solver = FixedShapedSolver(grammar, RuleNode(1))
        @test next_solution!(solver) == RuleNode(1)
        @test isnothing(next_solution!(solver))
    end

    @testset "No solutions (ordered constraint)" begin
        grammar = @csgrammar begin
            Number = 1
            Number = x
            Number = Number + Number
            Number = Number - Number
        end
        constraint1 = Ordered(RuleNode(3, [
            VarNode(:a),
            VarNode(:b)
        ]), [:a, :b])
        constraint2 = Ordered(RuleNode(4, [
            VarNode(:a),
            VarNode(:b)
        ]), [:a, :b])
        addconstraint!(grammar, constraint1)
        addconstraint!(grammar, constraint2)
        
        tree = FixedShapedHole(BitVector((0, 0, 1, 1)), [
            FixedShapedHole(BitVector((0, 0, 1, 1)), [
                FixedShapedHole(BitVector((1, 1, 0, 0)), []),
                FixedShapedHole(BitVector((1, 1, 0, 0)), [])
            ]),
            FixedShapedHole(BitVector((1, 1, 0, 0)), [])
        ])
        solver = FixedShapedSolver(grammar, tree)
        @test isnothing(next_solution!(solver))
    end

    @testset "No solutions (forbidden constraint)" begin
        grammar = @csgrammar begin
            Number = 1
            Number = x
            Number = Number + Number
            Number = Number - Number
        end
        constraint1 = Forbidden(RuleNode(3, [
            VarNode(:a),
            VarNode(:b)
        ]))
        constraint2 = Forbidden(RuleNode(4, [
            VarNode(:a),
            VarNode(:b)
        ]))
        addconstraint!(grammar, constraint1)
        addconstraint!(grammar, constraint2)
        
        tree = FixedShapedHole(BitVector((0, 0, 1, 1)), [
            FixedShapedHole(BitVector((0, 0, 1, 1)), [
                FixedShapedHole(BitVector((1, 1, 0, 0)), []),
                FixedShapedHole(BitVector((1, 1, 0, 0)), [])
            ]),
            FixedShapedHole(BitVector((1, 1, 0, 0)), [])
        ])
        solver = FixedShapedSolver(grammar, tree)
        @test isnothing(next_solution!(solver))
    end
end
