#TODO: StateHole should be a extending from an abstract FixedShapedHole
"""
	StateHole <: Hole

`StateHole`s are uniform holes used by the `FixedShapedSolver`. Domain manipulations are tracked for backpropagation.
- `domain`: A `StateSparseSet` representing the rule nodes this hole can take. If size(domain) == 1, this hole should act like a `RuleNode`
- `children`: The children of this hole in the expression tree.
"""
mutable struct StateHole <: Hole
	domain::StateSparseSet
	children::Vector{AbstractRuleNode}
end


"""
Converts a [`FixedShapedHole`](@ref) to a [`StateHole`](@ref)
"""
function StateHole(sm::StateManager, hole::FixedShapedHole)
	sss_domain = StateSparseSet(sm, hole.domain)
	children = [StateHole(sm, child) for child ∈ hole.children]
	return StateHole(sss_domain, children)
end


"""
Converts a [`RuleNode`](@ref) to a [`StateHole`](@ref)
"""
function StateHole(sm::StateManager, rulenode::RuleNode)
	children = [StateHole(sm, child) for child ∈ rulenode.children]
	return RuleNode(rulenode.ind, children)
end


HerbCore.isfixedshaped(::StateHole) = true


"""
	get_rule(hole::StateHole)::Int

Assuming the hole has domain size 1, get the rule it is currently assigned to.
"""
function HerbCore.get_rule(hole::StateHole)::Int
	#TODO: get_rule(n::RuleNode) = n.ind
	@assert isfilled(hole) "$(hole) has not been filled yet, unable to get the rule"
	return findfirst(hole.domain)
end


"""
	isfilled(hole::StateHole)::Bool

Holes with domain size 1 are fixed to a rule.
Returns whether the hole has domain size 1. (holes with an empty domain are not considered to be fixed)
"""
function HerbCore.isfilled(hole::StateHole)::Bool
	#TODO: isfilled(::Hole) = false
	#TODO: isfilled(::RuleNode) = true
	return size(hole.domain) == 1
end


"""
	contains_hole(hole::StateHole)::Bool

Returns true if the `hole` or any of its (grand)children are not filled.
"""
function HerbCore.contains_hole(hole::StateHole)::Bool
	if !isfilled(hole)
		return true
	end
	return any(contains_hole(c) for c ∈ hole.children)
end


function Base.show(io::IO, node::StateHole; separator=",", last_child::Bool=false)
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

HerbCore.get_children(hole::StateHole) = hole.children


"""
	freeze_state(hole::StateHole)::RuleNode

Converts a [`StateHole`])(@ref) to a [`RuleNode`]@(ref).
The hole and its children are assumed to be filled.
"""
function freeze_state(hole::StateHole)::RuleNode
	return RuleNode(get_rule(hole), [freeze_state(c) for c in hole.children])
end

function freeze_state(node::RuleNode)::RuleNode
	return RuleNode(node.ind, [freeze_state(c) for c in node.children])
end
