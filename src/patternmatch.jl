"""
    abstract type PatternMatchResult end

A result of the `pattern_match` function. Can be one of 4 cases:
- [`PatternMatchSuccess`](@ref) when the pattern matches exactly.
- [`PatternMatchHardFail`](@ref) when the pattern does not match (and there is no refinement of any holes in the tree such that it would match--some pair of domains is disjoint between the node and the pattern)
- [`PatternMatchSuccessWhenHoleAssignedTo`](@ref) when the pattern matches except for one hole, and all that is needed to make the pattern match is for that hole's domain to be assigned to one from a set of values.
- [`PatternMatchSoftFail`](@ref) when the pattern *could* match, depending on the way holes are refined.
"""
abstract type PatternMatchResult end

"""
The pattern is exactly matched and does not involve any holes at all
"""
struct PatternMatchSuccess <: PatternMatchResult end

"""
The pattern can be matched when the `hole` is filled with any of the given `ind`(s). Only one hole is involved.
"""
struct PatternMatchSuccessWhenHoleAssignedTo <: PatternMatchResult
    hole::AbstractHole
    ind::Union{Int, Vector{Int}}
    
    function PatternMatchSuccessWhenHoleAssignedTo(hole, ind)
        @assert !isempty(ind)
        return new(hole, length(ind) == 1 ? only(ind) : ind)
    end
end

"""
The pattern is not matched and can never be matched by filling in holes. 
"""
struct PatternMatchHardFail <: PatternMatchResult end

"""
The pattern can still be matched in a non-trivial way. Includes two cases:
- multiple holes are involved. this result stores a reference to one of them
- a single hole is involved, but needs to be filled with a node of size >= 2
"""
struct PatternMatchSoftFail <: PatternMatchResult
    hole::AbstractHole
end

@kwdef struct MatchState{H, V}
    hole::Union{Nothing,H}
    target_domain::Union{Nothing,Vector{Int}}
    vars::V
    disjoint::Bool
    found_big_hole::Bool
    n_holes::Int

    function MatchState{H, V}(hole::H, target_domain, vars::V, disjoint, found_big_hole, n_holes) where {H, V}
        ms = new{H, V}(hole, target_domain, vars, disjoint, found_big_hole, n_holes)
        @assert hardfail_state(ms) || success_state(ms) || match_when_hole_assigned_to_state(ms) || softfail_state(ms)
        return ms
    end
end

exit_early(ms) = hardfail_state(ms)

hardfail_state(ms) = is_hardfail(ms) && !(is_success(ms) || is_match_when_hole_assigned_to(ms) || is_softfail(ms))
is_hardfail(ms) = ms.disjoint

softfail_state(ms) = is_softfail(ms) && !(is_hardfail(ms) || is_success(ms) || is_match_when_hole_assigned_to(ms))
is_softfail(ms) = !ms.disjoint && !isnothing(ms.hole) && (ms.n_holes >= 2 || ms.found_big_hole)

success_state(ms) = is_success(ms) && !(is_hardfail(ms) || is_match_when_hole_assigned_to(ms) || is_softfail(ms))
is_success(ms) = !ms.disjoint && ms.n_holes == 0

match_when_hole_assigned_to_state(ms) = is_match_when_hole_assigned_to(ms) && !(is_hardfail(ms) || is_success(ms) || is_softfail(ms))
is_match_when_hole_assigned_to(ms) = !ms.disjoint && ms.n_holes == 1 && !ms.found_big_hole && !isnothing(ms.target_domain) && !isnothing(ms.hole)

function PatternMatchResult(st::MatchState)::PatternMatchResult
    if hardfail_state(st)
        return PatternMatchHardFail()
    end

    if match_when_hole_assigned_to_state(st)
        (; hole, target_domain) = st
        return PatternMatchSuccessWhenHoleAssignedTo(hole, target_domain)
    end
    if softfail_state(st)
        (; hole) = st
        return PatternMatchSoftFail(hole)
    end

    if success_state(st)
        return PatternMatchSuccess()
    end
    error("Unreachable, match state not in one of the expected configurations")
end

function get_big_hole_or_nothing(h1::H1, h2::H2) where {H1, H2}
    ch_def = HerbCore.has_definite_children.((H1, H2))
    if !ch_def[1] && ch_def[2] && !isempty(AT.children(h2))
        return h1
    elseif ch_def[1] && !ch_def[2] && !isempty(AT.children(h1))
        return h2
    else
        return nothing
    end
end

function intersect_domains(h1, h2)
    holes = (h1, h2)
    int = intersect(Base.to_index.(AT.nodevalue.(holes))...)

    return int
end

function update_match(state::M, zn) where M
    (; vars, n_holes, disjoint, hole, found_big_hole, target_domain) = state
    node1, node2 = HerbCore.nodes(zn)
    @assert !(node1 isa VarNode) "VarNodes are only allowed in the second argument of pattern_match"
    nv1, nv2 = AT.nodevalue(zn)

    if isdisjoint(nv1, nv2)
        return M(; hole, vars, disjoint = true, found_big_hole, n_holes, target_domain)
    end
    
    if node2 isa VarNode
        matching = get!(vars, nv2.name, node1)
        if matching !== node1
            match_res = get_final_match_result(matching, node1, vars)
            if success_state(match_res)
                match_res = get_final_match_result(node1, matching, vars)
            end
            if hardfail_state(match_res)
                return M(; hole, vars, disjoint = true, n_holes, found_big_hole, target_domain)
            end
            n_holes += match_res.n_holes
            hole = !isnothing(match_res.hole) ? match_res.hole : hole
            target_domain = !isnothing(match_res.target_domain) ? match_res.target_domain : target_domain
            found_big_hole = found_big_hole || match_res.found_big_hole 
        end
    end

    if !isfilled(node1) || !HerbCore.has_definite_children(typeof(node1))
        if !isnothing(get_big_hole_or_nothing(node1, node2))
            n_holes += 1
            hole = node1
            return M(; hole, vars, disjoint, found_big_hole=true, n_holes, target_domain)
        end
        int = intersect_domains(node1, node2)
        if length(nv1) > length(int)
            target_domain = int
            n_holes += 1
            hole = node1
        end
    end

    return M(; hole, vars, n_holes, disjoint, found_big_hole, target_domain)
end

function get_final_match_result(rn, mn, vars::V) where V
    dfs = AT.PreOrderDFS(zip(rn, mn))
    init = MatchState{Union{Nothing,AbstractHole}, V}(;
        hole = nothing,
        target_domain = nothing,
        vars,
        n_holes = 0,
        disjoint = false,
        found_big_hole = false
    )
    acc = Iterators.accumulate(update_match, dfs; init)
    stateful_acc = Iterators.Stateful(acc)

    st = popfirst!(stateful_acc)
    while !exit_early(st) && !Base.isdone(stateful_acc)
        st = popfirst!(stateful_acc)
    end
    return st
end

"""
    pattern_match(rn::AbstractRuleNode, mn::AbstractRuleNode)::PatternMatchResult

Recursively tries to match [`AbstractRuleNode`](@ref) `rn` with [`AbstractRuleNode`](@ref) `mn`.
Returns a `PatternMatchResult` that describes if the pattern was matched.
"""
function pattern_match(rn::AbstractRuleNode, mn::AbstractRuleNode, vars=Dict{Symbol, AbstractRuleNode}())::PatternMatchResult
    st = get_final_match_result(rn, mn, vars)
    return PatternMatchResult(st)
end
