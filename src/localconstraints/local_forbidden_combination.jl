"""
    LocalForbiddenCombination

Forbids any subtree at `path` whose root matches `root` and whose children
match one of the child tuples in `children`.
"""
@auto_hash_equals struct LocalForbiddenCombination <: AbstractLocalConstraint
    path::Vector{Int}
    root::AbstractRuleNode
    children::Vector{Vector{AbstractRuleNode}}
end

function _forbidden_combination_pattern(root::RuleNode, children::Vector{AbstractRuleNode})
    return RuleNode(get_rule(root), children)
end

function _forbidden_combination_pattern(root::DomainRuleNode, children::Vector{AbstractRuleNode})
    return DomainRuleNode(copy(root.domain), children)
end

function _forbidden_combination_root_match(
    node::AbstractRuleNode,
    root::RuleNode,
    arity::Int,
)::PatternMatchResult
    rule = get_rule(root)
    if isfilled(node)
        get_rule(node) == rule || return PatternMatchHardFail()
        if node isa Hole && arity != 0
            return PatternMatchSoftFail(node)
        end
        return PatternMatchSuccess()
    end

    node.domain[rule] || return PatternMatchHardFail()
    if isuniform(node) || arity == 0
        return PatternMatchSuccessWhenHoleAssignedTo(node, rule)
    end
    return PatternMatchSoftFail(node)
end

function _forbidden_combination_root_match(
    node::AbstractRuleNode,
    root::DomainRuleNode,
    arity::Int,
)::PatternMatchResult
    if isfilled(node)
        rule = get_rule(node)
        (rule <= length(root.domain) && root.domain[rule]) || return PatternMatchHardFail()
        return PatternMatchSuccess()
    end

    are_disjoint(node.domain, root.domain) && return PatternMatchHardFail()
    if length(get_children(node)) != arity
        return PatternMatchSoftFail(node)
    end
    is_subdomain(node.domain, root.domain) && return PatternMatchSuccess()

    intersection = get_intersection(node.domain, root.domain)
    @assert !isempty(intersection) "overlapping sets cannot have an empty intersection. the `are_disjoint` check failed."
    if length(intersection) == 1
        return PatternMatchSuccessWhenHoleAssignedTo(node, intersection[1])
    end
    return PatternMatchSuccessWhenHoleAssignedTo(node, intersection)
end

function _forbidden_combination_children_match(
    node::AbstractRuleNode,
    children::Vector{AbstractRuleNode},
)::PatternMatchResult
    empty!(VARS)
    return pattern_match(get_children(node), children, VARS)
end

_combine_forbidden_combination_match(
    ::PatternMatchSuccess,
    child_match::PatternMatchResult,
) = child_match

function _combine_forbidden_combination_match(
    root_match::PatternMatchSuccessWhenHoleAssignedTo,
    child_match::PatternMatchResult,
)::PatternMatchResult
    @match child_match begin
        ::PatternMatchHardFail => return child_match
        ::PatternMatchSoftFail => return child_match
        ::PatternMatchSuccess => return root_match
        match::PatternMatchSuccessWhenHoleAssignedTo => return PatternMatchSoftFail(match.hole)
    end
end

function propagate!(solver::Solver, c::LocalForbiddenCombination, when_satisfied)
    while isfeasible(solver)
        node = get_node_at_location(solver, c.path)
        arity = length(first(c.children))
        root_match = _forbidden_combination_root_match(node, c.root, arity)

        @match root_match begin
            ::PatternMatchHardFail => begin
                when_satisfied(solver, c)
                return
            end
            ::PatternMatchSoftFail => return
            ::PatternMatchSuccess || ::PatternMatchSuccessWhenHoleAssignedTo => begin
            end
        end

        all_hardfail = true
        made_deduction = false

        for children in c.children
            match_result = _combine_forbidden_combination_match(
                root_match,
                _forbidden_combination_children_match(node, children),
            )
            @match match_result begin
                ::PatternMatchHardFail => begin
                end
                ::PatternMatchSoftFail => begin
                    all_hardfail = false
                end
                ::PatternMatchSuccess => begin
                    set_infeasible!(solver)
                    return
                end
                match::PatternMatchSuccessWhenHoleAssignedTo => begin
                    all_hardfail = false
                    path = vcat(c.path, get_path(node, match.hole))
                    remove!(solver, path, match.ind)
                    made_deduction = true
                    break
                end
            end
        end

        if made_deduction
            continue
        end
        if all_hardfail
            when_satisfied(solver, c)
        end
        return
    end
end
