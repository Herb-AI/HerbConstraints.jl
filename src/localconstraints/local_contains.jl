
"""
LocalContains

Enforces that a given `rule` appears at or below the given `path` at least once.
"""
struct LocalContains <: LocalConstraint
	path::Vector{Int}
    rule::Int
end

function propagate!(solver::Solver, c::LocalContains)
    node = get_node_at_location(solver, c.path)
    track!(solver.statistics, "LocalContains propagation")
    @match _contains(node, c.rule) begin
        true => begin 
            track!(solver.statistics, "LocalContains satisfied")
            deactivate!(solver, c)
        end
        false => begin 
            track!(solver.statistics, "LocalContains inconsistency")
            mark_infeasible!(solver)
        end
        holes::Vector{Hole} => begin
            @assert length(holes) > 0
            if length(holes) == 1
                if isfixedshaped(holes[1])
                    track!(solver.statistics, "LocalContains deduction")
                    path = vcat(c.path, get_node_path(node, holes[1]))
                    deactivate!(solver, c)
                    remove_all_but!(solver, path, c.rule)
                else
                    #we cannot deduce anything yet, new holes can appear underneath this hole
                    #TODO: optimize this by checking if the target rule can appear as a child of the fixedshaped hole
                    track!(solver.statistics, "LocalContains softfail (variableshapedhole)")
                end
            else
                #multiple holes can be set to the target value, no deduction can be made as this point
                #TODO: optimize by only repropagating if the number of holes involved is <= 2
                track!(solver.statistics, "LocalContains softfail (>= 2 holes)")
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
- `Vector{Hole}`, if the `node` contains the `rule` if one the `holes` gets filled with the target rule
"""
function _contains(node::AbstractRuleNode, rule::Int)::Union{Vector{Hole}, Bool}
    return _contains(node, rule, Vector{Hole}())
end

function _contains(node::AbstractRuleNode, rule::Int, holes::Vector{Hole})::Union{Vector{Hole}, Bool}
    if !isfixedshaped(node)
        #TODO: check if the rule might appear underneath this variable shaped hole later
        # for now, it is assumed this is always possible
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

function _contains(children::Vector{AbstractRuleNode}, rule::Int, holes::Vector{Hole})::Union{Vector{Hole}, Bool}
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