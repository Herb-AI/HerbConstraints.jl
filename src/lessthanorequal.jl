"""
    abstract type LessThanOrEqualResult end

A result of the `less_than_or_equal` function. Can be one of 3 cases:
- [`LessThanOrEqualSuccess`](@ref)
- [`LessThanOrEqualHardFail`](@ref)
- [`LessThanOrEqualSoftFail`](@ref)
"""
abstract type LessThanOrEqualResult end


"""
    struct LessThanOrEqualSuccess <: LessThanOrEqualResult

`node1` <= `node2` is guaranteed under all possible assignments of the holes involved.
- `isequal` is true iff `node1` == `node2`. This field is needed to handle tiebreakers in the dfs
"""
struct LessThanOrEqualSuccess <: LessThanOrEqualResult
    isequal::Bool
end


"""
    struct LessThanOrEqualHardFail <: LessThanOrEqualResult end

`node1` > `node2` is guaranteed under all possible assignments of the holes involved.
"""
struct LessThanOrEqualHardFail <: LessThanOrEqualResult end


"""
    struct LessThanOrEqualSoftFail <: LessThanOrEqualResult

`node1` <= `node2` and `node1` > `node2` are both possible depending on the assignment of `hole1` and `hole2`.
Includes two cases:
- hole2::AbstractHole: A failed `AbstractHole`-`AbstractHole` comparison. (e.g. Hole(BitVector((1, 0, 1))) vs Hole(BitVector((0, 1, 1))))
- hole2::Nothing: A failed `AbstractHole`-`RuleNode` comparison. (e.g. Hole(BitVector((1, 0, 1))) vs RuleNode(2))
"""
struct LessThanOrEqualSoftFail <: LessThanOrEqualResult
    hole1::AbstractHole
    hole2::Union{AbstractHole, Nothing}
end

LessThanOrEqualSoftFail(hole) = LessThanOrEqualSoftFail(hole, nothing)


"""
    function make_less_than_or_equal!(solver::Solver, n1::AbstractRuleNode, n2::AbstractRuleNode)::LessThanOrEqualResult

Ensures that n1<=n2 by removing impossible values from holes. Returns one of the following results:
- [`LessThanOrEqualSuccess`](@ref). When [n1<=n2].
- [`LessThanOrEqualHardFail`](@ref). When [n1>n2] or when the solver state is infeasible.
- [`LessThanOrEqualSoftFail`](@ref). When no further deductions can be made, but [n1<=n2] and [n1>n2] are still possible.
"""
function make_less_than_or_equal!(
    solver::Solver,
    nodes1::Vector{AbstractRuleNode},
    nodes2::Vector{AbstractRuleNode}
)::LessThanOrEqualResult
    for (node1, node2) ∈ zip(nodes1, nodes2)
        result = make_less_than_or_equal!(solver, node1, node2)
        @match result begin
            ::LessThanOrEqualSuccess => if !result.isequal return result end;
            ::LessThanOrEqualHardFail => return result;
            ::LessThanOrEqualSoftFail => return result;
        end
    end
    return LessThanOrEqualSuccess(true)
end


function make_less_than_or_equal!(
    solver::Solver,
    node1::RuleNode,
    node2::RuleNode
)::LessThanOrEqualResult
    if get_rule(node1) < get_rule(node2)
        return LessThanOrEqualSuccess(false)
    elseif get_rule(node1) > get_rule(node2)
        return LessThanOrEqualHardFail()
    end
    return make_less_than_or_equal!(solver, node1.children, node2.children)
end


function make_less_than_or_equal!(
    solver::Solver,
    hole::AbstractHole,
    node::RuleNode
)
    path = get_path(get_tree(solver), hole) #TODO: optimize. very inefficient to go from hole->path->hole
    remove_above!(solver, path, get_rule(node))
    if !isfeasible(solver)
        return LessThanOrEqualHardFail()
    end
    #the hole might be replaced with a node, so we need to get whatever is at that location now
    @match get_node_at_location(solver, path) begin
        filledhole::RuleNode => return make_less_than_or_equal!(solver, filledhole, node)
        hole::AbstractHole => return LessThanOrEqualSoftFail(hole)
    end
end


function make_less_than_or_equal!(
    solver::Solver,
    node::RuleNode,
    hole::AbstractHole
)
    path = get_path(get_tree(solver), hole) #TODO: optimize. very inefficient to go from hole->path->hole
    remove_below!(solver, path, get_rule(node))
    if !isfeasible(solver)
        return LessThanOrEqualHardFail()
    end
    #the hole might be replaced with a node, so we need to get whatever is at that location now
    @match get_node_at_location(solver, path) begin
        filledhole::RuleNode => return make_less_than_or_equal!(solver, node, filledhole)
        hole::AbstractHole => return LessThanOrEqualSoftFail(hole)
    end
end


function make_less_than_or_equal!(
    solver::Solver,
    hole1::AbstractHole,
    hole2::AbstractHole
)
    left_highest_ind = findlast(hole1.domain)
    right_lowest_ind = findfirst(hole2.domain)
    if left_highest_ind <= right_lowest_ind
        # For example: Hole[1, 0, 1, 0, 0, 0] <= Hole[0, 0, 1, 1, 0, 1]
        return LessThanOrEqualSuccess(false)
    end
    left_lowest_ind = findfirst(hole1.domain)
    right_highest_ind = findlast(hole2.domain)
    if left_lowest_ind > right_highest_ind
        #For example: Hole[0, 0, 0, 1, 1, 1] > Hole[1, 1, 0, 0, 0, 0]
        return LessThanOrEqualHardFail()
    end
    return LessThanOrEqualSoftFail(hole1, hole2)
end


#TODO: all `make_less_than_or_equal!` functions for `StateHole`s are untested and copied from similar cases
#TODO: refactor the entire family of `make_less_than_or_equal!` functions to be more type resilient
#TODO: write unit tests for `make_less_than_or_equal!` with `StateHole`


function make_less_than_or_equal!(
    solver::Solver,
    hole::StateHole,
    node::RuleNode
)
    @assert size(hole.domain) > 0
    path = get_path(get_tree(solver), hole) #TODO: optimize. very inefficient to go from hole->path->hole
    remove_above!(solver, path, get_rule(node))
    if !isfeasible(solver)
        return LessThanOrEqualHardFail()
    end
    if isfilled(hole)
        #(node, node)-case
        if get_rule(hole) < get_rule(node)
            return LessThanOrEqualSuccess(false)
        elseif get_rule(hole) > get_rule(node)
            return LessThanOrEqualHardFail()
        end
        return make_less_than_or_equal!(solver, hole.children, node.children)
    else
        #(hole, node)-case
        return LessThanOrEqualSoftFail(hole)
    end
end


function make_less_than_or_equal!(
    solver::Solver,
    node::RuleNode,
    hole::StateHole
)
    @assert size(hole.domain) > 0
    path = get_path(get_tree(solver), hole) #TODO: optimize. very inefficient to go from hole->path->hole
    remove_below!(solver, path, get_rule(node))
    if !isfeasible(solver)
        return LessThanOrEqualHardFail()
    end
    if isfilled(hole)
        #(node, node)-case
        if get_rule(node) < get_rule(hole)
            return LessThanOrEqualSuccess(false)
        elseif get_rule(node) > get_rule(hole)
            return LessThanOrEqualHardFail()
        end
        return make_less_than_or_equal!(solver, node.children, hole.children)
    else
        #(node, hole)-case
        return LessThanOrEqualSoftFail(hole)
    end
end

function make_less_than_or_equal!(
    solver::Solver,
    hole1::StateHole,
    hole2::StateHole
)
    @assert (size(hole1.domain) > 0) && (size(hole2.domain) > 0)
    @match (isfilled(hole1), isfilled(hole2)) begin
        (true, true) => begin
            if get_rule(hole1) < get_rule(hole2)
                return LessThanOrEqualSuccess(false)
            elseif get_rule(hole1) > get_rule(hole2)
                return LessThanOrEqualHardFail()
            end
            return make_less_than_or_equal!(solver, hole1.children, hole2.children)
        end
        (true, false) => begin
            path = get_path(get_tree(solver), hole2) #TODO: optimize. very inefficient to go from hole->path->hole
            remove_below!(solver, path, get_rule(hole1))
            if !isfeasible(solver)
                return LessThanOrEqualHardFail()
            end
            if isfilled(hole2)
                #(node, node)-case
                if get_rule(hole1) < get_rule(hole2)
                    return LessThanOrEqualSuccess(false)
                elseif get_rule(hole1) > get_rule(hole2)
                    return LessThanOrEqualHardFail()
                end
                return make_less_than_or_equal!(solver, hole1.children, hole2.children)
            else
                #(node, hole)-case
                return LessThanOrEqualSoftFail(hole2)
            end
        end
        (false, true) => begin
            path = get_path(get_tree(solver), hole1) #TODO: optimize. very inefficient to go from hole->path->hole
            remove_above!(solver, path, get_rule(hole2))
            if !isfeasible(solver)
                return LessThanOrEqualHardFail()
            end
            if isfilled(hole1)
                #(node, node)-case
                if get_rule(hole1) < get_rule(hole2)
                    return LessThanOrEqualSuccess(false)
                elseif get_rule(hole1) > get_rule(hole2)
                    return LessThanOrEqualHardFail()
                end
                return make_less_than_or_equal!(solver, hole1.children, hole2.children)
            else
                #(hole, node)-case
                return LessThanOrEqualSoftFail(hole1)
            end
        end
        (false, false) => begin
            left_highest_ind = findlast(hole1.domain)
            right_lowest_ind = findfirst(hole2.domain)
            if left_highest_ind <= right_lowest_ind
                # For example: Hole[1, 0, 1, 0, 0, 0] <= Hole[0, 0, 1, 1, 0, 1]
                return LessThanOrEqualSuccess(false)
            end
            left_lowest_ind = findfirst(hole1.domain)
            right_highest_ind = findlast(hole2.domain)
            if left_lowest_ind > right_highest_ind
                #For example: Hole[0, 0, 0, 1, 1, 1] > Hole[1, 1, 0, 0, 0, 0]
                return LessThanOrEqualHardFail()
            end
            return LessThanOrEqualSoftFail(hole1, hole2)
        end
    end
end
