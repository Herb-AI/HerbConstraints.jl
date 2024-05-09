
"""
LocalContains

Enforces that a given `tree` appears at or below the given `path` at least once.

!!! warning:
    This is a stateful constraint can only be propagated by the UniformSolver
"""
mutable struct LocalContainsSubtree <: AbstractLocalConstraint
	path::Vector{Int}
    tree::AbstractRuleNode
    candidates::Union{Vector{AbstractRuleNode}, Nothing}
    indices::Union{StateSparseSet, Nothing}
end


function propagate!(::GenericSolver, ::LocalContainsSubtree)
    throw(ArgumentError("LocalContainsSubtree cannot be propagated by the GenericSolver"))
end

"""
    function propagate!(solver::UniformSolver, c::LocalContainsSubtree)

Enforce that the `tree` appears at or below the `path` at least once.
Uses a helper function to retrieve a list of holes that can potentially hold the target rule.
If there is only a single hole that can potentially hold the target rule, that hole will be filled with that rule.
"""
function propagate!(solver::UniformSolver, c::LocalContainsSubtree)
    track!(solver, "LocalContainsSubtree propagation")
    if isnothing(c.indices)
        if isnothing(c.candidates)
            # initial propagating: find the candidates
            c.candidates = Vector{AbstractRuleNode}()
            _set_candidates!(c, get_node_at_location(solver, c.path))
        end
        n = length(c.candidates)
        if n == 0
            track!(solver, "LocalContainsSubtree inconsistency (0 candidates)")
            set_infeasible!(solver)
            return
        elseif n == 1
            @match make_equal!(solver, c.candidates[1], c.tree) begin
                ::MakeEqualSuccess => begin 
                    track!(solver, "LocalContainsSubtree deduction (1 candidate)")
                    deactivate!(solver, c);
                    return;
                end 
                ::MakeEqualHardFail => begin 
                    track!(solver, "LocalContainsSubtree inconsistency (1 candidate)")
                    set_infeasible!(solver);
                    return;
                end 
                ::MakeEqualSoftFail => begin
                    track!(solver, "LocalContainsSubtree softfail (1 candidate)");
                    return
                end 
            end
        else
            c.indices = StateSparseSet(solver.sm, n)
        end
    else
        # check which candidates are still candidates. if there is only a single candidate left, enforce it becomes the target tree
        for i ∈ c.indices
            if pattern_match(c.candidates[i], c.tree) isa PatternMatchHardFail
                remove!(c.indices, i)
            end
        end
        n = length(c.indices)
        if n == 0
            track!(solver, "LocalContainsSubtree inconsistency (0 candidates remaining)")
            set_infeasible!(solver)
            return
        elseif n == 1
            @match make_equal!(solver, c.candidates[findfirst(c.indices)], c.tree) begin
                ::MakeEqualSuccess => begin 
                    track!(solver, "LocalContainsSubtree deduction (1 candidate remaining)")
                    deactivate!(solver, c);
                    return
                end 
                ::MakeEqualHardFail => begin 
                    track!(solver, "LocalContainsSubtree inconsistency (1 candidate remaining)")
                    set_infeasible!(solver);
                    return
                end 
                ::MakeEqualSoftFail => begin
                    track!(solver, "LocalContainsSubtree softfail (1 candidate remaining)");
                    return
                end 
            end
        end
    end
    track!(solver, "LocalContainsSubtree softfail (>=2 candidates)")
end

"""
    _set_candidates!(c::LocalContainsSubtree, tree::AbstractRuleNode)

Recursive helper function that stores all candidate matches.
All nodes in the `tree` that can potentially become the target tree `c.tree` are considered a candidate.
"""
function _set_candidates!(c::LocalContainsSubtree, tree::AbstractRuleNode)
    if !(pattern_match(c.tree, tree) isa PatternMatchHardFail)
        push!(c.candidates, tree)
    end
    for child ∈ get_children(tree)
        _set_candidates!(c, child)
    end
end

