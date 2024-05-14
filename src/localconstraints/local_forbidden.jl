
"""
    LocalForbidden

Forbids the a subtree that matches the `tree` to be generated at the location 
provided by the path. 
Use a `Forbidden` constraint for enforcing this throughout the entire search space.
"""
struct LocalForbidden <: AbstractLocalConstraint
    path::Vector{Int}
    tree::AbstractRuleNode
end

"""
    function propagate!(solver::Solver, c::LocalForbidden)

Enforce that the forbidden `tree` does not occur at the `path`.
The forbidden tree is matched against the [`AbstractRuleNode`](@ref) located at the path.
Deductions are based on the type of the [`PatternMatchResult`](@ref) returned by the [`pattern_match`](@ref) function.
"""
function propagate!(solver::Solver, c::LocalForbidden)
    node = get_node_at_location(solver, c.path)
    track!(solver, "LocalForbidden propagation")
    @match pattern_match(node, c.tree) begin
        ::PatternMatchHardFail => begin 
            # A match fail means that the constraint is already satisfied.
            # This constraint does not have to be re-propagated.
            deactivate!(solver, c)
            track!(solver, "LocalForbidden hardfail")
        end;
        match::PatternMatchSoftFail => begin 
            # The constraint needs to be re-propagated
            track!(solver, "LocalForbidden softfail")
        end
        ::PatternMatchSuccess => begin 
            # The forbidden tree is exactly matched. This means the state is infeasible.
            track!(solver, "LocalForbidden inconsistency")
            set_infeasible!(solver) #throw(InconsistencyException())
        end
        match::PatternMatchSuccessWhenHoleAssignedTo => begin
            # Propagate the constraint by removing an impossible value from the found hole.
            # Then, constraint is satisfied and does not have to be re-propagated.
            track!(solver, "LocalForbidden deduction")
            #path = get_path(get_tree(solver), match.hole)
            path = vcat(c.path, get_path(node, match.hole))
            deactivate!(solver, c)
            remove!(solver, path, match.ind)
        end
    end
end
