# include("../HerbConstraints.jl")

"""
Meta-constraint that enforces the disjunction of its given constraints.
"""
mutable struct LocalDisjunctive <: LocalConstraint
    first::PropagatorConstraint
    second::PropagatorConstraint
end


"""
Propagates the LocalDisjunctive constraint.
It enforces that at least one of its given constraints hold.
"""
function propagate(c::LocalDisjunctive, g::Grammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}
    # Propagate the two member propagators
    first_new_domain, first_new_constraints = propagate(c.first, g, context, copy(domain))
    second_new_domain, second_new_constraints = propagate(c.second, g, context, copy(domain))

    # Take the union of the two resulting domains
    new_domains::Vector{Int} = unique!([first_new_domain; second_new_domain])
    
    # Return itself if neither were removed
    if first_new_constraints != [] && second_new_constraints != []
        return new_domains, [c]
    end

    # return the first constraint if it was not removed
    if first_new_constraints != []
        return new_domains, c.first
    end

    # return the second constraint if it was not removed
    if second_new_constraints != []
        return new_domains, c.second
    end

    # return no remaining constraints if both were removed
    return new_domains, []
end