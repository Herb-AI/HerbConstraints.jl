#TODO: StateFixedShapedHole should be a extending from an abstract FixedShapedHole
"""
	StateFixedShapedHole <: Hole

- `domain`: A `StateSparseSet` representing the rule nodes this hole can take. If size(domain) == 1, this hole should act like a `RuleNode`
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


"""
	get_rule(hole::StateFixedShapedHole)::Int

Return the rule this hole is currently assigned to.
"""
function get_rule(hole::StateFixedShapedHole)::Int
	@assert isassigned(hole) "$(hole) has not been assigned yet, unable to get the rule"
	return findfirst(hole.domain)
end


"""
	isassigned(hole::StateFixedShapedHole)::Bool

Assuming the hole has domain size 1, get the rule it is currently assigned to.
"""
function isassigned(hole::StateFixedShapedHole)::Bool
	return size(hole.domain) == 1
end


function Base.show(io::IO, node::StateFixedShapedHole; separator=",", last_child::Bool=false)
	print(io, "statehole[$(node.domain)]")
	if !isempty(node.children)
	    print(io, "{")
	    for (i,c) in enumerate(node.children)
		show(io, c, separator=separator, last_child=(i == length(node.children)))
	    end
	    print(io, "}")
	elseif !last_child
	    print(io, separator)
	end
end

HerbCore.get_children(hole::StateFixedShapedHole) = hole.children
