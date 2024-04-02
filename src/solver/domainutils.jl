"""
     is_subdomain(subdomain::BitVector, domain::BitVector)

Checks if `subdomain` is a subdomain of `domain`.
Example: [0, 0, 1, 0] is a subdomain of [0, 1, 1, 1]
"""
function is_subdomain(subdomain::BitVector, domain::BitVector)
    return all(.!subdomain .| domain)
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
