"""
Enforces an order over two or more subtrees that fill the variables 
specified in `order` when the pattern is applied at the location given by `path`.
Use an `Ordered` constraint for enforcing this throughout the entire search space.
"""
mutable struct LocalOrdered <: LocalConstraint
    path::Vector{Int}
    tree::AbstractRuleNode
    order::Vector{Symbol}
end

function propagate!(solver::Solver, c::LocalOrdered)
    @assert is_feasible(solver)
    node = get_node_at_location(solver, c.path)
    track!(solver.statistics, "LocalOrdered propagation")
    vars = Dict{Symbol, AbstractRuleNode}()
    @match pattern_match(node, c.tree, vars) begin
        ::PatternMatchHardFail => begin 
            # A match fail means that the constraint is already satisfied.
            # This constraint does not have to be re-propagated.
            deactivate!(solver, c)
            track!(solver.statistics, "LocalOrdered match hardfail")
        end;
        ::PatternMatchSoftFail || ::PatternMatchSuccessWhenHoleAssignedTo => begin 
            # The constraint will re-propagated on any tree manipulation.
            # TODO: set a watcher, only propagate when needed.
            track!(solver.statistics, "LocalOrdered match softfail")
            propagate_on_tree_manipulation!(solver, c, Vector{Int}()) #TODO: should be c.path
        end
        ::PatternMatchSuccess => begin 
            # The forbidden tree is exactly matched. 
            for (name1, name2) ∈ zip(c.order[1:end-1], c.order[2:end])
                #remove values is handled inside make_less_than_or_equal!
                @match make_less_than_or_equal!(solver, vars[name1], vars[name2]) begin
                    ::LessThanOrEqualHardFail => begin
                        # vars[name1] > vars[name2]. This means the state is infeasible.
                        track!(solver.statistics, "LocalOrdered inconsistency")
                        mark_infeasible(solver) #throw(InconsistencyException())
                    end
                    ::LessThanOrEqualSoftFail => begin
                        # vars[name1] <= vars[name2] and vars[name1] > vars[name2] still possible
                        # Repropagate later.
                        # TODO: use the holes referenced inside the softfail for more efficient path-based repropagation
                        propagate_on_tree_manipulation!(solver, c, Vector{Int}()) #TODO: should be c.path
                    end
                    ::LessThanOrEqualSuccess => begin
                        # vars[name1] <= vars[name2]. the constaint is satisfied
                        # No repropagation needed
                        deactivate!(solver, c)
                    end
                end
            end
        end
    end
end
