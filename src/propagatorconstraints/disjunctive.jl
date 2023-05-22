"""
Meta-constraint that enforces the disjunction of its given constraints.
"""
struct Disjunctive <: PropagatorConstraint
    first::PropagatorConstraint
    second::PropagatorConstraint
end

"""
Propagates the Disjunctive constraint.
It enforces that at least one of its given constraints hold.
"""
function propagate(c::Disjunctive, g::Grammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}
    disjunctive_constraint = LocalDisjunctive(c.first, c.second)
    new_domain, new_constraints = propagate(disjunctive_constraint, g, context, domain)
    return new_domain, new_constraints
end