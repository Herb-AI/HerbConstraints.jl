
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

function propagate!(solver::Solver, c::LocalForbidden)
    node = get_node_at_location(solver, c.path)
    @match pattern_match(node, c.tree) begin
        ::PatternMatchHardFail => begin 
            # A match fail means that the constraint is already satisfied.
            # This constraint does not have to be re-propagated.
        end;
        ::PatternMatchSoftFail => begin 
            # The constraint will re-propagated on any tree manipulation.
            # TODO: set a watcher, only propagate when needed.
            propagate_on_tree_manipulation!(solver, c)
        end
        ::PatternMatchSuccess => begin 
            # The forbidden tree is exactly matched. This means the state is infeasible.
            mark_infeasible(solver) #throw(InconsistencyException())
        end
        match::PatternMatchSuccessWhenHoleAssignedTo => begin
            # Propagate the constraint by removing an impossible value from the found hole.
            # Then, constraint is satisfied and does not have to be re-propagated.
            remove!(solver, get_node_path(get_tree(solver), match.hole), match.ind)
        end
    end
end
