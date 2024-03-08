"""
    abstract type LessThanOrEqualResult end

A result of the `less_than_or_equal` function. Can be one of 3 cases:
- [`LessThanOrEqualSuccess`](@ref)
- [`LessThanOrEqualHardFail`](@ref)
- [`LessThanOrEqualSoftFail`](@ref)
"""
abstract type LessThanOrEqualResult end


"""
`node1` <= `node2` is guaranteed under all possible assignments of the holes involved.
"""
struct LessThanOrEqualSuccess <: LessThanOrEqualResult end


"""
`node1` > `node2` is guaranteed under all possible assignments of the holes involved.
"""
struct LessThanOrEqualHardFail <: LessThanOrEqualResult end


"""
`node1` <= `node2` and `node1` > `node2` are both possible depending on the assignment of `hole1` and `hole2`.
Includes two cases:
- hole2::Hole: A failed `Hole`-`Hole` comparison. (e.g. Hole(BitVector((1, 0, 1))) vs Hole(BitVector((0, 1, 1))))
- hole2::Nothing: A failed `Hole`-`RuleNode` comparison. (e.g. Hole(BitVector((1, 0, 1))) vs RuleNode(2))
"""
struct LessThanOrEqualSoftFail <: LessThanOrEqualResult
    hole1::Hole
    hole2::Union{Hole, Nothing}
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
            ::LessThanOrEqualSuccess => ();
            ::LessThanOrEqualHardFail => return result;
            ::LessThanOrEqualSoftFail => return result;
        end
    end
    return LessThanOrEqualSuccess()
end


function make_less_than_or_equal!(
    solver::Solver,
    node1::RuleNode,
    node2::RuleNode
)::LessThanOrEqualResult
    if node1.ind < node2.ind
        return LessThanOrEqualSuccess()
    elseif node1.ind > node2.ind
        return LessThanOrEqualHardFail()
    end
    return make_less_than_or_equal!(solver, node1.children, node2.children)
end


function make_less_than_or_equal!(
    solver::Solver,
    hole::Hole,
    node::RuleNode
)
    path = get_node_path(get_tree(solver), hole) #TODO: optimize. very inefficient to go from hole->path->hole
    remove_above!(solver, path, node.ind)
    if !is_feasible(solver)
        return LessThanOrEqualHardFail()
    end
    #the hole might be replaced with a node, so we need to get whatever is at that location now
    @match get_node_at_location(solver, path) begin
        filledhole::RuleNode => return make_less_than_or_equal!(solver, filledhole, node)
        hole::Hole => return LessThanOrEqualSoftFail(hole)
    end
end


function make_less_than_or_equal!(
    solver::Solver,
    node::RuleNode,
    hole::Hole
)
    path = get_node_path(get_tree(solver), hole) #TODO: optimize. very inefficient to go from hole->path->hole
    remove_below!(solver, path, node.ind)
    if !is_feasible(solver)
        return LessThanOrEqualHardFail()
    end
    #the hole might be replaced with a node, so we need to get whatever is at that location now
    @match get_node_at_location(solver, path) begin
        filledhole::RuleNode => return make_less_than_or_equal!(solver, node, filledhole)
        hole::Hole => return LessThanOrEqualSoftFail(hole)
    end
end


function make_less_than_or_equal!(
    solver::Solver,
    hole1::Hole,
    hole2::Hole
)
    left_highest_ind = findlast(hole1.domain)
    right_lowest_ind = findfirst(hole2.domain)
    if left_highest_ind <= right_lowest_ind
        # For example: Hole[1, 0, 1, 0, 0, 0] <= Hole[0, 0, 1, 1, 0, 1]
        return LessThanOrEqualSuccess()
    end
    left_lowest_ind = findfirst(hole1.domain)
    right_highest_ind = findlast(hole2.domain)
    if left_lowest_ind > right_highest_ind
        #For example: Hole[0, 0, 0, 1, 1, 1] > Hole[1, 1, 0, 0, 0, 0]
        return LessThanOrEqualHardFail()
    end
    return LessThanOrEqualSoftFail(hole1, hole2)
end