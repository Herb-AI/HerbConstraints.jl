
"""
    LocalUnique <: AbstractLocalConstraint

Enforces that a given `rule` appears at or below the given `path` at most once.
"""
struct LocalUnique <: AbstractLocalConstraint
	path::Vector{Int}
    rule::Int
end

"""
    function propagate!(solver::Solver, c::LocalUnique)

Enforce that the `rule` appears at or below the `path` at least once.
Uses a helper function to retrieve a list of holes that can potentially hold the target rule.
If there is only a single hole that can potentially hold the target rule, that hole will be filled with that rule.
"""
function propagate!(solver::Solver, c::LocalUnique)
    node = get_node_at_location(solver, c.path)
    holes = Vector{AbstractHole}()
    count = _count_occurrences!(node, c.rule, holes)
    track!(solver, "LocalUnique propagation")
    if count >= 2
        set_infeasible!(solver)
        track!(solver, "LocalUnique inconsistency")
    elseif count == 1
        if all(isuniform(hole) for hole ∈ holes)
            track!(solver, "LocalUnique deactivate")
            deactivate!(solver, c)
        end 
        for hole ∈ holes
            deductions = 0
            if hole.domain[c.rule] == true
                path = get_path(get_tree(solver), hole)
                remove!(solver, path, c.rule)
                deductions += 1
                track!(solver, "LocalUnique deduction ($(deductions))")
            end
        end
    end
end

"""
    function _count_occurrences!(node::AbstractRuleNode, rule::Int, holes::Vector{AbstractHole})::Int

Recursive helper function for the LocalUnique constraint.
Returns the number of certain occurrences of the rule in the tree.
All holes that potentially can hold the target rule are stored in the `holes` vector.

!!! warning: 
    Stops counting if the rule occurs more than once. 
    Counting beyond 2 is not needed for LocalUnique. 
"""
function _count_occurrences!(node::AbstractRuleNode, rule::Int, holes::Vector{AbstractHole})::Int
    count = 0
    if isfilled(node)
        # if the rulenode is the second occurence of the rule, hardfail
        if get_rule(node) == rule
            count += 1
            if count > 1
                return count
            end
        end
    else
        # if the hole contains the target rule, add the hole to the candidate list
        if !isuniform(node) || node.domain[rule] == true
            push!(holes, node)
        end
    end
    for child ∈ get_children(node)
        count += _count_occurrences!(child, rule, holes)
        if count > 1
            return count
        end
    end
    return count
end
