struct Programmatic <: PropagatorConstraint
    tree::AbstractMatchNode
    condition::Function
end
    

function propagate(c::Programmatic, g::Grammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}
    ordered_constraint = LocalProgrammatic(context.nodeLocation, c.tree, c.condition)
    new_domain, new_constraints = propagate(ordered_constraint, g, context, domain)
    return new_domain, new_constraints
end
