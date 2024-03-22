"""
     is_subdomain(subdomain::BitVector, domain::BitVector)

Checks if `subdomain` is a subdomain of `domain`.
Example: [0, 0, 1, 0] is a subdomain of [0, 1, 1, 1]
"""
function is_subdomain(subdomain::BitVector, domain::BitVector)
    return all(.!subdomain .| domain)
end
function is_subdomain(subdomain::StateSparseSet, domain::BitVector)
    for v ∈ subdomain
        if !domain[v]
            return false
        end
    end
    return true
end

"""
    partition(hole::VariableShapedHole, grammar::ContextSensitiveGrammar)::Vector{BitVector}

Partition a [VariableShapedHole](@ref) into subdomains grouped by childtypes
"""
function partition(hole::VariableShapedHole, grammar::ContextSensitiveGrammar)::Vector{BitVector}
    domain = copy(hole.domain)
    fixed_shaped_domains = []
    while true
        rule = findfirst(domain)
        if isnothing(rule)
            break
        end
        fixed_shaped_domain = grammar.bychildtypes[rule] .& hole.domain
        push!(fixed_shaped_domains, fixed_shaped_domain)
        domain .-= fixed_shaped_domain
    end
    return fixed_shaped_domains
end

"""
    are_disjoint(domain1::BitVector, domain2::BitVector)::Bool

Returns true if there is no overlap in values between `domain1` and `domain2`
"""
function are_disjoint(domain1::BitVector, domain2::BitVector)::Bool
    return all(.!domain1 .| .!domain2)
end
are_disjoint(bitvector::BitVector, sss::StateSparseSet)::Bool = are_disjoint(sss, bitvector)
function are_disjoint(sss::StateSparseSet, bitvector::BitVector)
    for v ∈ sss
        if bitvector[v]
            return false
        end
    end
    return true
end

"""
    get_intersection(domain1::BitVector, domain2::BitVector)::Bool

Returns all the values that are in both `domain1` and `domain2`
"""
function get_intersection(domain1::BitVector, domain2::BitVector)::Vector{Int}
    return findall(domain1 .& domain2)
end
function get_intersection(sss::Union{BitVector, StateSparseSet}, domain2::Union{BitVector, StateSparseSet})::Vector{Int}
    if !(sss isa StateSparseSet) 
        sss, domain2 = domain2, sss
        @assert sss isa StateSparseSet
    end
    intersection = Vector{Int}()
    for v ∈ sss
        if domain2[v]
            push!(intersection, v)
        end
    end
    return intersection
end
