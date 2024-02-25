"""
Checks if `subdomain` is a subdomain of `domain`.

Example: [0, 0, 1, 0] is a subdomain of [0, 1, 1, 1]
"""
function is_subdomain(subdomain::BitVector, domain::BitVector)
    return all(.!subdomain .| domain)
end

"""
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
