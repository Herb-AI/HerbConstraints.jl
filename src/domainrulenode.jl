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

struct StableGrammarDomainRuleNode{G<:AbstractGrammar,C} <: AbstractRuleNode
    grammar::G
    domain::BitVector
    children::Vector{StableGrammarDomainRuleNode}
end

# struct StableDomainRuleNode <: AbstractRuleNode
#     domain::BitVector
#
# end

const EMPTY_STABLE_GRAMMAR_DOMAIN_RULENODE = StableGrammarDomainRuleNode[]

function StableGrammarDomainRuleNode(grammar, domain=trues(length(get_rules(grammar))), children=EMPTY_STABLE_GRAMMAR_DOMAIN_RULENODE)
    length(domain) == length(get_rules(grammar)) || error(lazy"Domain size ($(length(domain))) must match grammar size ($(length(get_rules(grammar))))")
    return StableGrammarDomainRuleNode{typeof(grammar),typeof(children)}(grammar, domain, children)
end

get_grammar(sgdrn::StableGrammarDomainRuleNode) = sgdrn.grammar
HerbCore.get_rule(sgdrn::StableGrammarDomainRuleNode) = sgdrn.domain
HerbCore.get_domain(sgdrn::StableGrammarDomainRuleNode) = sgdrn.domain
HerbCore.get_children(sgdrn::StableGrammarDomainRuleNode) = sgdrn.children

function HerbCore.isuniform(sgdrn::StableGrammarDomainRuleNode)
    child_types = get_grammar(sgdrn).childtypes[get_domain(sgdrn)]
    return allequal(child_types) && length(get_children(sgdrn)) == length(first(child_types))
end

function HerbGrammar.isterminal(sgdrn::StableGrammarDomainRuleNode)
    return all(get_grammar(sgdrn).isterminal[get_domain(sgdrn)])
end

function DomainRuleNode(grammar::AbstractGrammar, rules::Vector{Int}, children::Vector{<:AbstractRuleNode})
    domain = falses(length(grammar.rules))
    domain[rules] .= true
    # n children per rule in the domain
    n_children = length.(grammar.childtypes[domain])

    if !(allequal(n_children) && n_children[1] == length(children))
        error("""Could not create DomainRuleNode. The number of children for \
              each rule in the domain must be equal (rules $rules have \
              $n_children children respectively). The length of the \
              `children` vector ($(length(children))) must also match.""")
    end

    return DomainRuleNode(domain, children)
end

DomainRuleNode(grammar::AbstractGrammar, rules::Vector{Int}) = DomainRuleNode(grammar, rules, Vector{AbstractRuleNode}())

#DomainRuleNode(get_domain(grammar, sym), [])
DomainRuleNode(domain::BitVector) = DomainRuleNode(domain, [])

"""
    update_rule_indices!(node::DomainRuleNode, n_rules::Integer)

Updates the `DomainRuleNode` by resizing the domain vector to `n_rules`. 
Errors if the length of the domain vector exceeds new `n_rules`.

# Arguments
- `node`: The current `DomainRuleNode` being processed
- `n_rules`: The new number of rules in the grammar
"""
function HerbCore.update_rule_indices!(node::DomainRuleNode, n_rules::Integer)
    if length(node.domain) > n_rules
        error("Length domain vector $(length(node.domain)) exceeds the number of grammar rules $(n_rules).")
    end
    append!(node.domain, falses(n_rules - length(node.domain)))
    for child in node.children
        HerbCore.update_rule_indices!(child, n_rules)
    end
end

"""
	update_rule_indices!(node::DomainRuleNode, n_rules::Integer, mapping::AbstractDict{<:Integer, <:Integer})

Updates the `DomainRuleNode` by resizing the domain vector to `n_rules` and remapping rule indices based `mapping`. 
Errors if the length of the domain vector exceeds new `n_rules`.

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

# Check if `DomainRuleNode`'s domain length matches `n_rules`.
function HerbCore.is_domain_valid(node::DomainRuleNode, n_rules::Integer)
    if length(node.domain) != n_rules
        return false
    end
    all(child -> HerbCore.is_domain_valid(child, n_rules), get_children(node))
end

function Base.:(==)(A::DomainRuleNode, B::DomainRuleNode)

    A.domain == B.domain && length(A.children) == length(B.children) && all(HerbCore.isequal(a, b) for (a, b) in zip(A.children, B.children))

end

function HerbGrammar.is_tree_valid(drn::DomainRuleNode, grammar::AbstractGrammar, _expected_type::Symbol; allow_empty_children::Bool)::Bool
    # DomainRuleNode can have multiple expected types -> ignore the provided.
    length(grammar.rules) == length(drn.domain) || return false
    child_types = grammar.childtypes[drn.domain]
    return HerbGrammar._are_children_valid(drn, grammar, child_types; allow_empty_children=allow_empty_children)
end

function HerbGrammar.is_tree_valid(drn::DomainRuleNode, grammar::AbstractGrammar; allow_empty_children::Bool)::Bool
    return HerbGrammar.is_tree_valid(drn, grammar, :any; allow_empty_children=allow_empty_children)
end
