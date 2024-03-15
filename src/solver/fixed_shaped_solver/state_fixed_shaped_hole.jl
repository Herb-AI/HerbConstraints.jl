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

Assuming the hole has domain size 1, get the rule it is currently assigned to.
"""
function get_rule(hole::StateFixedShapedHole)::Int
	#TODO: get_rule(n::RuleNode) = n.ind
	@assert isfilled(hole) "$(hole) has not been filled yet, unable to get the rule"
	return findfirst(hole.domain)
end


"""
	isfilled(hole::StateFixedShapedHole)::Bool

Holes with domain size 1 are fixed to a rule.
Returns whether the hole has domain size 1.
"""
function isfilled(hole::StateFixedShapedHole)::Bool
	#TODO: isfilled(::Hole) = false
	#TODO: isfilled(::RuleNode) = true
	return size(hole.domain) == 1
end


"""
	contains_hole(hole::StateFixedShapedHole)::Bool

Returns true if the `hole` or any of its (grand)children are not filled.
"""
function HerbCore.contains_hole(hole::StateFixedShapedHole)::Bool
	if !isfilled(hole)
		return true
	end
	return any(contains_hole(c) for c ∈ hole.children)
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
