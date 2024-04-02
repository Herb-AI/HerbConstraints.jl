
"""
    LocalForbidden

Forbids the a subtree that matches the `tree` to be generated at the location 
provided by the path. 
Use a `Forbidden` constraint for enforcing this throughout the entire search space.
"""
struct LocalForbidden <: LocalConstraint
    path::Vector{Int}
    tree::AbstractRuleNode
end

function propagate!(solver::Solver, c::LocalForbidden)
    node = get_node_at_location(solver, c.path)
    track!(solver.statistics, "LocalForbidden propagation")
    @match pattern_match(node, c.tree) begin
        ::PatternMatchHardFail => begin 
            # A match fail means that the constraint is already satisfied.
            # This constraint does not have to be re-propagated.
            track!(solver.statistics, "LocalForbidden hardfail")
        end;
        match::PatternMatchSoftFail => begin 
            # The constraint will re-propagated on any tree manipulation.
            # TODO: set a watcher, only propagate when needed.
            track!(solver.statistics, "LocalForbidden softfail")
            #path = vcat(c.path, get_node_path(node, match.hole))
            propagate_on_tree_manipulation!(solver, c, Vector{Int}()) #TODO: should be c.path
        end
        ::PatternMatchSuccess => begin 
            # The forbidden tree is exactly matched. This means the state is infeasible.
            track!(solver.statistics, "LocalForbidden inconsistency")
            mark_infeasible(solver) #throw(InconsistencyException())
        end
        match::PatternMatchSuccessWhenHoleAssignedTo => begin
            # Propagate the constraint by removing an impossible value from the found hole.
            # Then, constraint is satisfied and does not have to be re-propagated.
            track!(solver.statistics, "LocalForbidden deduction")
            #path = get_node_path(get_tree(solver), match.hole)
            path = vcat(c.path, get_node_path(node, match.hole))
            remove!(solver, path, match.ind)
        end
    end
end
