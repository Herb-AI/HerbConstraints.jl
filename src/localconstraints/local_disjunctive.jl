# include("../HerbConstraints.jl")

"""
Meta-constraint that enforces the disjunction of its given constraints.
"""
mutable struct LocalDisjunctive <: LocalConstraint
    constraints::Vector{PropagatorConstraint}
end


"""
Propagates the LocalDisjunctive constraint.
It enforces that at least one of its given constraints hold.
"""
function propagate(c::LocalDisjunctive, g::Grammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}
    # Special case for when the constraint is empty
    if length(c.constraints) == 0
        return domain, []
    end
    
    # Set up lists (with empty elements for domains)
    res_domains::Vector{Int} = fill!(resize!(Vector(), length(domain)), -1)
    res_constraints::Vector{LocalConstraint} = []
    res_constraints_count::Int = 0

    # Loop over all constraints
    for constraint ∈ c.constraints
        # Propagate the constraints
        new_domain, new_constraints = propagate(constraint, g, context, copy(domain))

        # Append the new constraints to the result
        res_constraints = [res_constraints; new_constraints]
        if new_constraints == [constraint]
            res_constraints_count += 1
        end

        # Add all domain values in the correct spots
        for v ∈ new_domain
            res_domains[findfirst(isequal(v), domain)] = v
        end
    end

    # Filter all empty elements in domains
    # (this ensures that the order of the domains remains the same)
    filter!(!=(-1), res_domains)

    # Return the original constraint if all constraints returned themselves
    if res_constraints_count == length(c.constraints)
        return res_domains, [c]
    end

    # Return all constraints that were returned
    return res_domains, res_constraints
end
