"""
Meta-constraint that enforces the disjunction of its given constraints.
"""
mutable struct LocalOneOf <: LocalConstraint
    global_constraints::Vector{PropagatorConstraint}
    local_constraints::Set{LocalConstraint}
end


"""
Propagates the LocalOneOf constraint.
It enforces that at least one of its given constraints hold.
"""
function propagate(
    c::LocalOneOf, 
    g::AbstractGrammar, 
    context::AbstractGrammarContext, 
    domain::Vector{Int},
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{PropagatedDomain, Set{LocalConstraint}} 
    if length(c.global_constraints) == 0
        return domain, Set()
    end

    # Copy the context to add the local constraints belonging to this one of constraint as well.
    # This way, we don't unnecessarily keep creating new local constraints.
    new_context = deepcopy(context)
    union!(new_context.constraints, c.local_constraints)

    new_local_constraints::Set{LocalConstraint} = Set()
    new_domain = BitVector(undef, length(g.rules))

    # Iterate over the global constraints & local constraints
    any_domain_updated = false
    for constraint ∈ Iterators.flatten((c.global_constraints, c.local_constraints))
        curr_domain, curr_local_constraints = propagate(constraint, g, new_context, copy(domain), filled_hole)

        # If we are actually intending to update the domain, OR it and set the domain updated flag to true.
        if !isa(curr_domain, PropagateFailureReason)
            new_domain .|= get_domain(g, curr_domain)
            any_domain_updated = true
        end

        union!(new_local_constraints, curr_local_constraints)
    end

    # If we have updated the domain, use that domain. Otherwise, simply return the original domain.
    returned_domain = any_domain_updated ? findall(new_domain) : domain

    # Make a copy of the one of constraint. Otherwise, every tree will have the same reference to it (as we only create 1).
    return returned_domain, Set([LocalOneOf(c.global_constraints, new_local_constraints)])
end
