
"""
LocalContains

Enforces that a given `rule` appears at or below the given `path` at least once.
"""
struct LocalContains <: AbstractLocalConstraint
	path::Vector{Int}
    rule::Int
end

"""
    function propagate!(solver::Solver, c::LocalContains)

Enforce that the `rule` appears at or below the `path` at least once.
Uses a helper function to retrieve a list of holes that can potentially hold the target rule.
If there is only a single hole that can potentially hold the target rule, that hole will be filled with that rule.
"""
function propagate!(solver::Solver, c::LocalContains)
    node = get_node_at_location(solver, c.path)
    track!(solver, "LocalContains propagation")
    @match _contains(node, c.rule) begin
        true => begin 
            track!(solver, "LocalContains satisfied")
            deactivate!(solver, c)
        end
        false => begin 
            track!(solver, "LocalContains inconsistency")
            set_infeasible!(solver)
        end
        holes::Vector{AbstractHole} => begin
            @assert length(holes) > 0
            if length(holes) == 1
                if isuniform(holes[1])
                    track!(solver, "LocalContains deduction")
                    path = vcat(c.path, get_path(node, holes[1]))
                    deactivate!(solver, c)
                    remove_all_but!(solver, path, c.rule)
                else
                    # we cannot deduce anything yet, new holes can appear underneath this hole
                    # optimize this by checking if the target rule can appear as a child of the hole
                    track!(solver, "LocalContains softfail (non-uniform hole)")
                end
            else
                # multiple holes can be set to the target value, no deduction can be made as this point
                # optimize by only repropagating if the number of holes involved is <= 2
                track!(solver, "LocalContains softfail (>= 2 holes)")
            end
        end
    end
end

"""
    _contains(node::AbstractRuleNode, rule::Int)::Bool

Recursive helper function for the LocalContains constraint
Returns one of the following:
- `true`, if the `node` does contains the `rule`
- `false`, if the `node` does not contain the `rule`
- `Vector{AbstractHole}`, if the `node` contains the `rule` if one the `holes` gets filled with the target rule
"""
function _contains(node::AbstractRuleNode, rule::Int)::Union{Vector{AbstractHole}, Bool}
    return _contains(node, rule, Vector{AbstractHole}())
end

function _contains(node::AbstractRuleNode, rule::Int, holes::Vector{AbstractHole})::Union{Vector{AbstractHole}, Bool}
    if !isuniform(node)
        # the rule might appear underneath this non-uniform hole
        push!(holes, node)
    elseif isfilled(node)
        # if the rulenode is the target rule, return true
        if get_rule(node) == rule
            return true
        end
    else
        # if the hole contains the target rule, add the hole to the candidate list
        if node.domain[rule] == true
            push!(holes, node)
        end
    end
    return _contains(get_children(node), rule, holes)
end

function _contains(children::Vector{AbstractRuleNode}, rule::Int, holes::Vector{AbstractHole})::Union{Vector{AbstractHole}, Bool}
    for child ∈ children
        if _contains(child, rule, holes) == true
            return true
        end
    end
    if isempty(holes)
        return false
    end
    return holes
end
