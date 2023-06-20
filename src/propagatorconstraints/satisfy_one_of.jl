"""
Meta-constraint that enforces the disjunction of its given constraints.
"""
struct SatisfyOneOf <: PropagatorConstraint
    constraints::Vector{PropagatorConstraint}
end

function SatisfyOneOf(constraint::PropagatorConstraint) return SatisfyOneOf([constraint]) end
function SatisfyOneOf(constraints...) return SatisfyOneOf([constraints...]) end


"""
Propagates the SatisfyOneOf constraint.
It enforces that at least one of its given constraints hold.
"""
function propagate(
    c::SatisfyOneOf, 
    g::Grammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{PropagatedDomain, Set{LocalConstraint}}
    # Only ever create 1 instance mounted at the root. We do require a local constraint to have multiple instances (one for every PQ node).
    if context.nodeLocation != [] return unchanged_domain, Set() end

    satisfy_one_of_constraint = LocalSatisfyOneOf(c.constraints, Set())
    new_domain, new_constraints = propagate(satisfy_one_of_constraint, g, context, domain, filled_hole)
    return new_domain, new_constraints
end


"""
Checks if the given tree abides the constraint.
"""
function check_tree(c::SatisfyOneOf, g::Grammar, tree::AbstractRuleNode)::Bool
    return any(check_tree(cons, g, tree) for cons in c.constraints)
end