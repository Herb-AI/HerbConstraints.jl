"""
Meta-constraint that enforces the disjunction of its given constraints.
"""
struct Disjunctive <: PropagatorConstraint
    constraints::Vector{PropagatorConstraint}
end


# Varargs constructors
function Disjunctive(constraint::PropagatorConstraint) return Disjunctive([constraint]) end
function Disjunctive(constraints...) return Disjunctive([constraints...]) end


"""
Propagates the Disjunctive constraint.
It enforces that at least one of its given constraints hold.
"""
function propagate(
    c::Disjunctive,
    g::Grammar,
    context::GrammarContext,
    domain::Vector{Int},
    ::Union{HoleReference, Nothing}
)::Tuple{Vector{Int}, Set{LocalConstraint}}
    disjunctive_constraint = LocalDisjunctive(c.constraints)
    new_domain, new_constraints = propagate(disjunctive_constraint, g, context, domain)
    return new_domain, new_constraints
end
