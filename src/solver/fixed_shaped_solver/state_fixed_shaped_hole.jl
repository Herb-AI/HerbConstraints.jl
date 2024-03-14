#TODO: StateFixedShapedHole should be a extending from an abstract FixedShapedHole
"""
    StatefulFixedShapedHole <: Hole

- `domain`: A bitvector, where the `i`th bit is set to true if the `i`th rule in the grammar can be applied. All rules in the domain are required to have the same childtypes.
- `children`: The children of this hole in the expression tree.
"""
mutable struct StateFixedShapedHole <: Hole
	domain::StateSparseSet
	children::Vector{AbstractRuleNode}
end

"""
Converts a [`FixedShapedHole`](@ref) to a [`StateFixedShapedHole`](@ref)
"""
function StateFixedShapedHole(sm::StateManager, hole::FixedShapedHole)
	sss_domain = StateSparseSet(sm, hole.domain)
	children = [StateFixedShapedHole(sm, child) for child ∈ hole.children]
	return StateFixedShapedHole(sss_domain, children)
end

"""
Converts a [`RuleNode`](@ref) to a [`StateFixedShapedHole`](@ref)
"""
function StateFixedShapedHole(sm::StateManager, rulenode::RuleNode)
	children = [StateFixedShapedHole(sm, child) for child ∈ rulenode.children]
	return RuleNode(rulenode.ind, children)
end
