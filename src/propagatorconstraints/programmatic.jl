struct Programmatic <: PropagatorConstraint
    tree::AbstractMatchNode
    condition::Function
end
    

function propagate(
    c::Programmatic, 
    g::Grammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{PropagatedDomain, Set{LocalConstraint}}
	# Skip the propagator if the hole that was filled isn't a parent of the current hole
	if !isnothing(filled_hole) && filled_hole.path != context.nodeLocation[begin:end-1]
		return unchanged_domain, Set()
	end

    programmatic_constraint = LocalProgrammatic(context.nodeLocation, c.tree, c.condition)
    if in(programmatic_constraint, context.constraints) return unchanged_domain, Set() end

    new_domain, new_constraints = propagate(programmatic_constraint, g, context, domain, filled_hole)
    return new_domain, new_constraints
end


"""
Checks if the given tree abides the constraint.
"""
function check_tree(c::Programmatic, g::Grammar, tree::AbstractRuleNode)::Bool
	@warn "Programmatic.check_tree not implemented!"

	return true
end