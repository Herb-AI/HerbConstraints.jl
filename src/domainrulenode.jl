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

function DomainRuleNode(grammar::AbstractGrammar, rules::Vector{Int}, children::Vector{<:AbstractRuleNode})
    domain = falses(length(grammar.rules))
    for r ∈ rules
        domain[r] = true
    end
    return DomainRuleNode(domain, children)
end

DomainRuleNode(grammar::AbstractGrammar, rules::Vector{Int}) = DomainRuleNode(grammar, rules, Vector{AbstractRuleNode}())

#DomainRuleNode(get_domain(grammar, sym), [])
DomainRuleNode(domain::BitVector) = DomainRuleNode(domain, [])

"""
Processes and updates current node in a tree as required when grammar size changes.
For `DomainRuleNode` instances, this function resizes the domain by adding zeros.
Recursively processes all child nodes of the tree.

# Arguments
- `node`: The current `DomainRuleNode` being processed
- `n_rules`: The new number of rules in the grammar
"""
function HerbCore.update_rule_indices!(node::DomainRuleNode, n_rules::Integer)
    append!(node.domain, falses(n_rules - length(node.domain)))
    for child in node.children
        HerbCore.update_rule_indices!(child, n_rules)
    end
end

"""
	update_rule_indices!(node::DomainRuleNode, n_rules::Integer, mapping::AbstractDict{<:Integer, <:Integer})

Processes and updates current node in a tree as required when grammar size changes.
For `DomainRuleNode` instances, this function remaps the rule indices based on `mapping` and resizes the domain by adding zeros.
Recursively processes all child nodes of the tree.

# Arguments
- `node`: The current `DomainRuleNode` being processed
- `n_rules`: The new number of rules in the grammar
- `mapping`: Dictionary mapping old rule indices to new rule indices
"""
function HerbCore.update_rule_indices!(
    node::DomainRuleNode,
    n_rules::Integer,
    mapping::AbstractDict{<:Integer,<:Integer},
)
    # resize domain 
    HerbCore.update_rule_indices!(node, n_rules)
    # remap rule indices
    rules = findall(node.domain)
    for r in rules
        if haskey(mapping, r)
            node.domain[r] = false
            node.domain[mapping[r]] = true
        end
    end
    children = get_children(node)
    for child in children
        HerbCore.update_rule_indices!(child, n_rules, mapping)
    end
end