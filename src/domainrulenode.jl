"""
    struct DomainRuleNode <: AbstractRuleNode

Matches any 1 rule in its domain.
Example usage:

    DomainRuleNode(Bitvector((0, 0, 1, 1)), [RuleNode(1), RuleNode(1)])

This matches `RuleNode(3, [RuleNode(1), RuleNode(1)])` and `RuleNode(4, [RuleNode(1), RuleNode(1)])` and `UniformHole({3, 4}, [RuleNode(1), RuleNode(1)])`
"""
struct DomainRuleNode <: AbstractRuleNode
    domain::BitVector
    children::Vector{AbstractRuleNode}
end

function DomainRuleNode(
        grammar::AbstractGrammar, rules::Vector{Int}, children::Vector{<:AbstractRuleNode})
    domain = falses(length(grammar.rules))
    for r in rules
        domain[r] = true
    end
    return DomainRuleNode(domain, children)
end

function DomainRuleNode(grammar::AbstractGrammar, rules::Vector{Int})
    DomainRuleNode(grammar, rules, Vector{AbstractRuleNode}())
end

#DomainRuleNode(get_domain(grammar, sym), [])
DomainRuleNode(domain::BitVector) = DomainRuleNode(domain, [])
