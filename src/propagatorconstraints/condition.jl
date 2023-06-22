struct Condition <: PropagatorConstraint
    tree::AbstractMatchNode
    condition::Function
end
    

function propagate(
    c::Condition, 
    g::Grammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{PropagatedDomain, Set{LocalConstraint}}
	# Skip the propagator if the hole that was filled isn't a parent of the current hole
	if !isnothing(filled_hole) && filled_hole.path != context.nodeLocation[begin:end-1]
        global prop_skip_count += 1
		return unchanged_domain, Set()
	end

    global prop_count += 1

    _condition_constraint = LocalCondition(context.nodeLocation, c.tree, c.condition)
    if in(_condition_constraint, context.constraints) return unchanged_domain, Set() end

    new_domain, new_constraints = propagate(_condition_constraint, g, context, domain, filled_hole)
    return new_domain, new_constraints
end


"""
Checks if the given tree abides the constraint.
"""
function check_tree(c::Condition, g::Grammar, tree::AbstractRuleNode)::Bool
	@warn "Condition.check_tree not implemented!"

	return true
end