struct SatisfyCondition <: PropagatorConstraint
    tree::AbstractMatchNode
    condition::Function
end
    

function propagate(
    c::SatisfyCondition, 
    g::Grammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{PropagatedDomain, Set{LocalConstraint}}
	# Skip the propagator if the hole that was filled isn't a parent of the current hole
	if !isnothing(filled_hole) && filled_hole.path != context.nodeLocation[begin:end-1]
		return unchanged_domain, Set()
	end

    satisfy_condition_constraint = LocalSatisfyCondition(context.nodeLocation, c.tree, c.condition)
    if in(satisfy_condition_constraint, context.constraints) return unchanged_domain, Set() end

    new_domain, new_constraints = propagate(satisfy_condition_constraint, g, context, domain, filled_hole)
    return new_domain, new_constraints
end


"""
Checks if the given tree abides the constraint.
"""
function check_tree(c::SatisfyCondition, g::Grammar, tree::AbstractRuleNode)::Bool
	@warn "SatisfyCondition.check_tree not implemented!"

	return true
end