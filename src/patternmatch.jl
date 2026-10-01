"""
    PatternMatchResult

A result of the `pattern_match` function. 4 subtypes are defined:

- `PatternMatchSuccess` when the pattern matches exactly.

- `PatternMatchHardFail` when the pattern does not match (and there is
    no refinement of any holes in the tree such that it would match--some pair of
    domains is disjoint between the node and the pattern).

- `PatternMatchSuccessWhenHoleAssignedTo` when the pattern matches
    except for one hole, and all that is needed to make the pattern match is for
    that hole's domain to be assigned to one from a set of values.

- `PatternMatchSoftFail` when the pattern *could* match, depending on
    the way holes are refined. Either:
    - More than one hole is involved, or
    - A single hole needs to be filled with a tree of size 2 or larger.
"""
abstract type PatternMatchResult end

struct PatternMatchSuccess <: PatternMatchResult end

struct PatternMatchSuccessWhenHoleAssignedTo <: PatternMatchResult
    hole::AbstractHole
    ind::Union{Int, Vector{Int}}
    
    function PatternMatchSuccessWhenHoleAssignedTo(hole, ind)
        @assert !isempty(ind)
        return new(hole, length(ind) == 1 ? only(ind) : ind)
    end
end

struct PatternMatchHardFail <: PatternMatchResult end

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
        @assert count((hardfail_state(ms), success_state(ms), match_when_hole_assigned_to_state(ms), softfail_state(ms))) == 1
        return ms
    end
end

hardfail_state(ms) = ms.disjoint
softfail_state(ms) = !ms.disjoint && !isnothing(ms.hole) && (ms.n_holes >= 2 || ms.found_big_hole)
success_state(ms) = !ms.disjoint && ms.n_holes == 0
function match_when_hole_assigned_to_state(ms)
    return (
        !ms.disjoint
        && ms.n_holes == 1
        && !ms.found_big_hole
        && !isnothing(ms.target_domain)
        && !isnothing(ms.hole)
    )
end

function PatternMatchResult(st::MatchState)
    if hardfail_state(st)
        return PatternMatchHardFail()
    elseif match_when_hole_assigned_to_state(st)
        (; hole, target_domain) = st
        return PatternMatchSuccessWhenHoleAssignedTo(hole, target_domain)
    elseif softfail_state(st)
        (; hole) = st
        return PatternMatchSoftFail(hole)
    elseif success_state(st)
        return PatternMatchSuccess()
    else
        error("Unreachable, match state not in one of the expected configurations")
    end
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
        # if not literally the same node
        # check that the two subtrees match
        if matching !== node1   
            match_res = get_final_match_result(matching, node1, vars)
            if success_state(match_res) # try swapping in case node1 is actually the "wider" node
                # meaning the node with the larger domain
                match_res = get_final_match_result(node1, matching, vars)
            end
            if hardfail_state(match_res)
                return M(; hole, vars, disjoint = true, n_holes, found_big_hole, target_domain)
            end
            # merge the sub-pattern match result into this one
            n_holes += match_res.n_holes
            hole = !isnothing(match_res.hole) ? match_res.hole : hole
            target_domain = !isnothing(match_res.target_domain) ? match_res.target_domain : target_domain
            found_big_hole = found_big_hole || match_res.found_big_hole 
        end
    end

    if !isfilled(node1) || !HerbCore.has_definite_children(typeof(node1))
        if !isnothing(get_big_hole_or_nothing(node1, node2))
            n_holes += 1
            hole = node1 # node1 would need to be filled with a tree of size > 2 to match
            return M(; hole, vars, disjoint, found_big_hole=true, n_holes, target_domain)
        end
        int = intersect_domains(node1, node2)
        if length(nv1) > length(int) # node1 will need to shrink to match `int`
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
    while !hardfail_state(st) && !Base.isdone(stateful_acc)
        st = popfirst!(stateful_acc)
    end
    return st
end

"""
    pattern_match(rn::AbstractRuleNode, mn::AbstractRuleNode)::PatternMatchResult

Recursively tries to match [`AbstractRuleNode`](@ref) `rn` with [`AbstractRuleNode`](@ref) `mn`.
Returns a `PatternMatchResult` that describes if the pattern was matched.
"""
function pattern_match(rn::AbstractRuleNode, mn::AbstractRuleNode, vars=Dict{Symbol, AbstractRuleNode}())
    st = get_final_match_result(rn, mn, vars)
    return PatternMatchResult(st)
end
