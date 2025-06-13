@testset verbose = true "DomainRuleNode" begin
    @testset "Update domain size only" begin
        node = DomainRuleNode(BitVector((1, 0)))
        n_rules = 5
        HerbCore.update_rule_indices!(node, n_rules)
        @test node.domain == BitVector((1, 0, 0, 0, 0))
    end
    @testset "Update domain size and remap indices" begin
        node = DomainRuleNode(BitVector((1, 0, 1)))
        n_rules = 10
        mapping = Dict(1 => 4, 3 => 6, 4 => 7)
        HerbCore.update_rule_indices!(node, n_rules, mapping)
        expected_domain = BitVector(zeros(n_rules))
        expected_domain[[4, 6...]] .= true
        @test node.domain == expected_domain
    end
    @testset "Update with children" begin
        node = DomainRuleNode(BitVector((1, 0)), [DomainRuleNode(BitVector((1, 1))), DomainRuleNode(BitVector((0, 1)))])
        n_rules = 4
        mapping = Dict(1 => 3, 2 => 4)
        HerbCore.update_rule_indices!(node, n_rules, mapping)
        @test node.domain == BitVector((0, 0, 1, 0))
        children = get_children(node)
        @test length(children) == 2
        @test children[1].domain == BitVector((0, 0, 1, 1))
        @test children[2].domain == BitVector((0, 0, 0, 1))
    end
    @testset "error" begin
        node = DomainRuleNode(BitVector((1, 0, 0, 0, 0)), [DomainRuleNode(BitVector((1, 1))), DomainRuleNode(BitVector((0, 1)))])
        n_rules = 3
        @test_throws ErrorException HerbCore.update_rule_indices!(node, n_rules)
    end
end