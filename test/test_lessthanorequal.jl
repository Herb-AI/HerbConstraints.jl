using HerbCore, HerbGrammar

@testset verbose=true "LessThanOrEqual" begin

    function create_dummy_solver(leftnode::AbstractRuleNode, rightnode::AbstractRuleNode)
        grammar = @csgrammar begin
            Number = x | 1
            Number = Number + Number
            Number = Number - Number
        end
        solver = Solver(grammar, :Number)
        tree = RuleNode(4, [
            leftnode,
            RuleNode(3, [
                RuleNode(2), 
                rightnode
            ])
        ])
        #tree = RuleNode(4, [leftnode, rightnode]) #more trivial case
        new_state!(solver, tree)
        return solver
    end

    @testset "HardFail, no holes, >" begin
        left = RuleNode(2)
        right = RuleNode(1)
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualHardFail
    end

    @testset "Success, no holes, ==" begin
        left = RuleNode(1)
        right = RuleNode(1)
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSuccess
    end

    @testset "Success, no holes, <" begin
        left = RuleNode(1)
        right = RuleNode(2)
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSuccess
    end

    @testset "Success, 1 hole (left)" begin
        left = Hole(BitVector((1, 0, 1, 0)))
        right = RuleNode(2)
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSuccess
    end

    @testset "Success, 1 hole (right), expands" begin
        left = RuleNode(2)
        right = Hole(BitVector((1, 0, 1, 0)))
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSuccess
    end

    @testset "Success, 2 holes" begin
        left = Hole(BitVector((1, 1, 0, 0)))
        right = Hole(BitVector((0, 0, 1, 1)))
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSuccess
    end

    @testset "HardFail, 1 hole (left)" begin
        left = Hole(BitVector((0, 0, 1, 1)))
        right = RuleNode(2)
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualHardFail
    end

    @testset "HardFail, 1 hole (right)" begin
        left = RuleNode(3, [RuleNode(1), RuleNode(1)])
        right = Hole(BitVector((1, 1, 0, 0)))
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualHardFail
    end

    @testset "HardFail, 2 holes" begin
        left = Hole(BitVector((0, 0, 1, 1)))
        right = Hole(BitVector((1, 1, 0, 0)))
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualHardFail
    end

    @testset "SoftFail, 2 holes" begin
        left = Hole(BitVector((0, 0, 1, 1)))
        right = Hole(BitVector((1, 0, 1, 0)))
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSoftFail
    end

    @testset "left hole softfails" begin
        left = Hole(BitVector((0, 1, 1, 0)))
        right = RuleNode(3, [RuleNode(2), RuleNode(2)])
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSoftFail
    end

    @testset "left hole gets filled once, then softfails" begin
        left = Hole(BitVector((0, 0, 1, 1)))
        right = RuleNode(3, [RuleNode(2), RuleNode(2)])
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSoftFail
        @test number_of_holes(get_tree(solver)) == 2
    end

    @testset "left hole gets filled twice, then softfails" begin
        left = Hole(BitVector((0, 0, 1, 1)))
        right = RuleNode(3, [RuleNode(1), RuleNode(2)])
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSoftFail
        @test number_of_holes(get_tree(solver)) == 1
    end

    @testset "left hole gets filled thrice, and succeeds" begin
        left = Hole(BitVector((0, 0, 1, 1)))
        right = RuleNode(3, [RuleNode(1), RuleNode(1)])
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSuccess
        @test number_of_holes(get_tree(solver)) == 0
    end

    @testset "right hole softfails" begin
        left = RuleNode(3, [RuleNode(2), RuleNode(2)])
        right = Hole(BitVector((0, 0, 1, 1)))
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSoftFail
    end

    @testset "right hole gets filled once, then softfails" begin
        left = RuleNode(4, [RuleNode(2), RuleNode(2)])
        right = Hole(BitVector((0, 0, 1, 1)))
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSoftFail
        @test number_of_holes(get_tree(solver)) == 2
    end

    @testset "right hole expands to 4 holes" begin
        left = RuleNode(4, [
            RuleNode(4, [
                RuleNode(4, [
                    RuleNode(2),
                    RuleNode(2)
                ]), 
            ]),
            RuleNode(4, [
                RuleNode(2),
                RuleNode(2)
            ]), 
        ])
        right = Hole(BitVector((0, 0, 1, 1)))
        solver = create_dummy_solver(left, right)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSoftFail
        @test number_of_holes(get_tree(solver)) == 4
    end

    @testset "Success, large tree" begin
        grammar = @csgrammar begin
            Int = |(1:9)
            Int = x
            Int = 0
            Int = Int + Int
            Int = Int - Int
            Int = Int * Int
        end
        domain = BitVector((1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1))
        left = RuleNode(13, [RuleNode(5), Hole(domain)])
        right = RuleNode(13, [RuleNode(11), RuleNode(1)])
        tree = RuleNode(14, [left, right])

        solver = Solver(grammar, :Int)
        new_state!(solver, tree)

        @test HerbConstraints.make_less_than_or_equal!(solver, left, right) isa HerbConstraints.LessThanOrEqualSuccess
        @test contains_variable_shaped_hole(get_tree(solver)) == true
        @test number_of_holes(get_tree(solver)) == 1
    end
end
