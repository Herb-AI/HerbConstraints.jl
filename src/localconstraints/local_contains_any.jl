"""
LocalContainsAny

Enforces that at least one of the given `rules` appears at or below the given `path`.
"""
struct LocalContainsAny <: AbstractLocalConstraint
    path::Vector{Int}
    rules::Vector{Int}
end

"""
    function propagate!(solver::Solver, c::LocalContainsAny)

Enforce that one of the rules appears at or below the `path` at least once.
Uses a helper function to retrieve a list of holes that can potentially hold any of the target rules.
If there is only a single hole that can potentially hold a target rule, that hole will be restricted
to the target rule subset.
"""
function propagate!(solver::Solver, c::LocalContainsAny)
    node = get_node_at_location(solver, c.path)
    @timeit_debug solver.statistics "LocalContainsAny propagation" begin end
    @match _contains_any(node, c.rules) begin
        true => begin
            @timeit_debug solver.statistics "LocalContainsAny satisfied" begin end
            deactivate!(solver, c)
        end
        false => begin
            @timeit_debug solver.statistics "LocalContainsAny inconsistency" begin end
            set_infeasible!(solver)
        end
        holes::Vector{AbstractHole} => begin
            @assert length(holes) > 0
            if length(holes) == 1
                if isuniform(holes[1])
                    @timeit_debug solver.statistics "LocalContainsAny deduction" begin end
                    path = vcat(c.path, get_path(node, holes[1]))
                    allowed_rules = [r for r in c.rules if holes[1].domain[r]]
                    deactivate!(solver, c)
                    remove_all_but!(solver, path, allowed_rules)
                else
                    # we cannot deduce anything yet, new holes can appear underneath this hole
                    # optimize this by checking if the target rule can appear as a child of the hole
                    @timeit_debug solver.statistics "LocalContainsAny softfail (non-uniform hole)" begin end
                end
            else
                # multiple holes can be set to the target value, no deduction can be made as this point
                # optimize by only repropagating if the number of holes involved is <= 2
                @timeit_debug solver.statistics "LocalContainsAny softfail (>= 2 holes)" begin end
            end
        end
    end
end

"""
    _contains_any(node::AbstractRuleNode, rules::Vector{Int})::Bool

Recursive helper function for the LocalContainsAny constraint.
Returns one of the following:
- `true`, if the `node` contains any of the rules
- `false`, if the `node` does not contain any of the rules
- `Vector{AbstractHole}`, if the `node` contains any rule if one of the `holes` gets filled with a target rule
"""
function _contains_any(node::AbstractRuleNode, rules::Vector{Int})::Union{Vector{AbstractHole},Bool}
    return _contains_any(node, rules, Vector{AbstractHole}())
end

function _contains_any(node::AbstractRuleNode, rules::Vector{Int}, holes::Vector{AbstractHole})::Union{Vector{AbstractHole},Bool}
    if !isuniform(node)
        # one of the rules might appear underneath this non-uniform hole
        push!(holes, node)
    elseif isfilled(node)
        # if the rulenode is one of the target rule, return true
        if get_rule(node) in rules
            return true
        end
    else
        # if the hole contains one of the target rule, add the hole to the candidate list
        if any(rule -> node.domain[rule] == true, rules)
            push!(holes, node)
        end
    end
    return _contains_any(get_children(node), rules, holes)
end

function _contains_any(children::Vector{AbstractRuleNode}, rules::Vector{Int}, holes::Vector{AbstractHole})::Union{Vector{AbstractHole},Bool}
    for child ∈ children
        if _contains_any(child, rules, holes) == true
            return true
        end
    end
    if isempty(holes)
        return false
    end
    return holes
end
