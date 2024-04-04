"""
    struct DomainRuleNode <: AbstractRuleNode

An abstraction of a rule node, designed to match any rule in its domain. Primarily used to summarize matching nodes of uniform shape. 

Example usage:

    DomainRuleNode(Bitvector((0, 0, 1, 1)), [RuleNode(1), RuleNode(1)])

This matches `RuleNode(3, [RuleNode(1), RuleNode(1)])` and `RuleNode(4, [RuleNode(1), RuleNode(1)])` and `Hole({3, 4}, [RuleNode(1), RuleNode(1)])`
"""
struct DomainRuleNode <: AbstractRuleNode
    domain::BitVector
    children::Vector{AbstractRuleNode}
end

#DomainRuleNode(get_domain(grammar, sym), [])
DomainRuleNode(domain::BitVector) = DomainRuleNode(domain, [])
