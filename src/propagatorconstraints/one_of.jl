"""
Meta-constraint that enforces the disjunction of its given constraints.
"""
struct OneOf <: PropagatorConstraint
    constraints::Vector{PropagatorConstraint}
end

function OneOf(constraint::PropagatorConstraint) return OneOf([constraint]) end
function OneOf(constraints...) return OneOf([constraints...]) end


"""
Propagates the OneOf constraint.
It enforces that at least one of its given constraints hold.
"""
function propagate(
    c::OneOf, 
    g::Grammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{PropagatedDomain, Set{LocalConstraint}}
    # Only ever create 1 instance mounted at the root. We do require a local constraint to have multiple instances (one for every PQ node).
    if context.nodeLocation != [] return unchanged_domain, Set() end

    global prop_count += 1

    _one_of_constraint = LocalOneOf(c.constraints, Set())
    new_domain, new_constraints = propagate(_one_of_constraint, g, context, domain, filled_hole)
    return new_domain, new_constraints
end


"""
Checks if the given tree abides the constraint.
"""
function check_tree(c::OneOf, g::Grammar, tree::AbstractRuleNode)::Bool
    return any(check_tree(cons, g, tree) for cons in c.constraints)
end