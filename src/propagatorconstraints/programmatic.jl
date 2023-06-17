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