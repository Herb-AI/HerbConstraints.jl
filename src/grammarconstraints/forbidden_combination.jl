"""
    ForbiddenCombination <: AbstractGrammarConstraint

Forbids a root rule/domain together with any of several child tuples. This is
equivalent to a conjunction of `Forbidden(root(children...))` constraints, but
keeps the alternatives grouped so children are not generalized independently.

# Example

`ForbiddenCombination(RuleNode(4), children=[[RuleNode(1), RuleNode(2)],
[RuleNode(3), RuleNode(5)]])` forbids `4{1,2}` and `4{3,5}`, but does not
forbid `4{1,5}` or `4{3,2}`.
"""
struct ForbiddenCombination <: AbstractGrammarConstraint
    root::AbstractRuleNode
    children::Vector{Vector{AbstractRuleNode}}

    function ForbiddenCombination(
        root::AbstractRuleNode,
        children::AbstractVector{<:AbstractVector{<:AbstractRuleNode}},
    )
        isempty(children) && error("ForbiddenCombination requires at least one child tuple.")

        normalized_root = _forbidden_combination_root(root)
        normalized_children = Vector{AbstractRuleNode}[
            AbstractRuleNode[child for child in child_tuple]
            for child_tuple in children
        ]
        arity = length(first(normalized_children))
        if any(child_tuple -> length(child_tuple) != arity, normalized_children)
            error("All ForbiddenCombination child tuples must have the same arity.")
        end

        return new(normalized_root, normalized_children)
    end
end

ForbiddenCombination(root::AbstractRuleNode; children) = ForbiddenCombination(root, children)
ForbiddenCombination(rule::Int, children::AbstractVector{<:AbstractVector{<:AbstractRuleNode}}) =
    ForbiddenCombination(RuleNode(rule), children)
ForbiddenCombination(rule::Int; children) = ForbiddenCombination(RuleNode(rule), children)

function _forbidden_combination_root(root::RuleNode)
    return RuleNode(get_rule(root))
end

function _forbidden_combination_root(root::DomainRuleNode)
    return DomainRuleNode(copy(root.domain), AbstractRuleNode[])
end

function _forbidden_combination_root(root::AbstractRuleNode)
    error("ForbiddenCombination root must be a RuleNode or DomainRuleNode, got $(typeof(root)).")
end

function _forbidden_combination_root_matches(node::AbstractRuleNode, root::RuleNode)::Bool
    if isfilled(node)
        return get_rule(node) == get_rule(root)
    end
    return node.domain[get_rule(root)]
end

function _forbidden_combination_root_matches(node::AbstractRuleNode, root::DomainRuleNode)::Bool
    if isfilled(node)
        rule = get_rule(node)
        return rule <= length(root.domain) && root.domain[rule]
    end
    return !are_disjoint(node.domain, root.domain)
end

local_constraint_types(::ForbiddenCombination) = LocalForbiddenCombination
function on_new_node(solver::Solver, c::ForbiddenCombination, path::Vector{Int})
    node = get_node_at_location(solver, path)
    _forbidden_combination_root_matches(node, c.root) || return
    post!(solver, LocalForbiddenCombination(path, c.root, c.children))
end

"""
    check_tree(c::ForbiddenCombination, tree::AbstractRuleNode)::Bool

Checks if the given tree avoids every forbidden root/children tuple.
"""
function check_tree(c::ForbiddenCombination, tree::AbstractRuleNode)::Bool
    arity = length(first(c.children))
    root_match = _forbidden_combination_root_match(tree, c.root, arity)

    @match root_match begin
        ::PatternMatchHardFail => begin
        end
        ::PatternMatchSoftFail => begin
        end
        ::PatternMatchSuccess || ::PatternMatchSuccessWhenHoleAssignedTo => begin
            for children in c.children
                match_result = _combine_forbidden_combination_match(
                    root_match,
                    _forbidden_combination_children_match(tree, children),
                )
                @match match_result begin
                    ::PatternMatchSuccess => return false
                    ::PatternMatchHardFail || ::PatternMatchSoftFail || ::PatternMatchSuccessWhenHoleAssignedTo => begin
                    end
                end
            end
        end
    end
    return all(child -> check_tree(c, child), get_children(tree))
end

function HerbCore.update_rule_indices!(
    c::ForbiddenCombination,
    n_rules::Integer,
)
    HerbCore.update_rule_indices!(c.root, n_rules)
    for child_tuple in c.children
        for child in child_tuple
            HerbCore.update_rule_indices!(child, n_rules)
        end
    end
end

function HerbCore.update_rule_indices!(
    c::ForbiddenCombination,
    grammar::AbstractGrammar,
)
    HerbCore.update_rule_indices!(c, length(grammar.rules))
end

function HerbCore.update_rule_indices!(
    c::ForbiddenCombination,
    n_rules::Integer,
    mapping::AbstractDict{<:Integer,<:Integer},
    ::Vector{<:AbstractConstraint},
)
    HerbCore.update_rule_indices!(c.root, n_rules, mapping)
    for child_tuple in c.children
        for child in child_tuple
            HerbCore.update_rule_indices!(child, n_rules, mapping)
        end
    end
end

function HerbCore.update_rule_indices!(
    c::ForbiddenCombination,
    grammar::AbstractGrammar,
    mapping::AbstractDict{<:Integer,<:Integer},
)
    HerbCore.update_rule_indices!(c, length(grammar.rules), mapping, grammar.constraints)
end

function HerbCore.is_domain_valid(c::ForbiddenCombination, n_rules::Integer)
    HerbCore.is_domain_valid(c.root, n_rules) || return false
    return all(
        child -> HerbCore.is_domain_valid(child, n_rules),
        Iterators.flatten(c.children),
    )
end

HerbCore.is_domain_valid(c::ForbiddenCombination, grammar::AbstractGrammar) =
    HerbCore.is_domain_valid(c, length(grammar.rules))

function _same_child_tuple(
    left::Vector{AbstractRuleNode},
    right::Vector{AbstractRuleNode},
)::Bool
    length(left) == length(right) || return false
    return all(HerbCore.issame(l, r) for (l, r) in zip(left, right))
end

function Base.:(==)(c1::ForbiddenCombination, c2::ForbiddenCombination)
    HerbCore.issame(c1.root, c2.root) || return false
    length(c1.children) == length(c2.children) || return false
    matched = falses(length(c2.children))
    for child_tuple in c1.children
        match_index = findfirst(i -> !matched[i] && _same_child_tuple(child_tuple, c2.children[i]), eachindex(c2.children))
        isnothing(match_index) && return false
        matched[match_index] = true
    end
    return true
end

function HerbGrammar.is_constraint_valid(c::ForbiddenCombination, grammar::AbstractGrammar; allow_empty_children::Bool)
    for children in c.children
        pattern = _forbidden_combination_pattern(c.root, children)
        HerbGrammar.is_tree_valid(pattern, grammar; allow_empty_children=allow_empty_children) || return false
    end
    return true
end
