"""
    Solver

Abstract constraint solver. 
Each solver should have at least the following fields:
- `statistics::SolverStatistics`
- `fix_point_running::Bool`
- `schedule::PriorityQueue{Constraint, Int}`

Each solver should implement at least:
- `post!`
- `get_tree`
- `get_grammar`
- `mark_infeasible`
- `is_feasible`
- `HerbCore.get_node_at_location`
- `get_hole_at_location`
- `propagate_on_tree_manipulation!`
- `notify_tree_manipulation`
- `deactivate!`
"""
abstract type Solver end


"""
    fix_point!(solver::Solver)

Propagate constraints in the current state until no further dedecutions can be made
"""
function fix_point!(solver::Solver)
    if solver.fix_point_running return end
    solver.fix_point_running = true
    while !isempty(solver.schedule)
        if !is_feasible(solver)
            #an inconsistency was found, stop propagating constraints and return
            empty!(solver.schedule)
            break
        end
        constraint = dequeue!(solver.schedule) 
        propagate!(solver, constraint)
    end
    solver.fix_point_running = false
end


"""
    schedule(solver::GenericSolver, constraint::Constraint)

Schedules the `constraint` for propagation.
"""
function schedule!(solver::Solver, constraint::Constraint)
    track!(solver.statistics, "schedule!")
    track!(solver.statistics, "schedule! $(typeof(constraint))")
    if constraint ∉ keys(solver.schedule)
        enqueue!(solver.schedule, constraint, 99) #TODO: replace `99` with `get_priority(c)`
    end
end
