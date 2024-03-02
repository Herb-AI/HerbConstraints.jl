
"""
    LocalForbidden

Forbids the a subtree that matches the MatchNode tree to be generated at the location 
provided by the path. 
Use a `Forbidden` constraint for enforcing this throughout the entire search space.
"""
mutable struct LocalForbidden <: LocalConstraint
	path::Vector{Int}
    tree::AbstractRuleNode
end

#if a constraint needs to be repropagated, it is responsible for calling `propagate_on_tree_manipulation`
function propagate!(solver::Solver, c::LocalForbidden)::Bool
    node = get_node_at_location(solver, c.path)
    @match pattern_match(node, c.tree) begin
        ::PatternMatchHardFail => begin 
            # Match attempt failed due to mismatched rulenode indices. 
            # This means that we can remove the current constraint.
            return true #TODO: deactivate this constraint
        end;
        ::PatternMatchSoftFail => begin 
            # Match attempt failed because we had to compare with a hole. 
            # If the hole would've been filled it might have succeeded, so we cannot yet remove the constraint.
            propagate_on_tree_manipulation!(solver, c)
            return true
        end
        ::PatternMatchSuccess => begin 
            #TODO: mark this state as infeasible
            return false
        end
        match::PatternMatchSuccessWhenHoleAssignedTo => begin
            remove!(solver, vcat(c.path, match.path), match.ind)
            return true #TODO: deactivate this constraint
        end
    end
end
