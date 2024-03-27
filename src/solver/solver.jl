"""
    Solver

Abstract constraint solver. 
Each solver should have at least the following fields:
- `statistics::SolverStatistics`
- `fix_point_running::Bool`
- `schedule::PriorityQueue{LocalConstraint, Int}`

Each solver should implement at least:
- `post!`
- `get_tree`
- `get_grammar`
- `mark_infeasible!`
- `isfeasible`
- `HerbCore.get_node_at_location`
- `get_hole_at_location`
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
        if !isfeasible(solver)
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
    schedule(solver::GenericSolver, constraint::LocalConstraint)

Schedules the `constraint` for propagation.
"""
function schedule!(solver::Solver, constraint::LocalConstraint)
    @assert isfeasible(solver)
    if constraint ∉ keys(solver.schedule)
        track!(solver.statistics, "schedule!")
        enqueue!(solver.schedule, constraint, 99) #TODO: replace `99` with `get_priority(c)`
    end
end


"""
    shouldschedule(solver::Solver, constraint::LocalConstraint, path::Vector{Int})::Bool

Function that is called when a tree manipulation occured at the `path`.
Returns true if the `constraint` should be scheduled for propagation.

Default behavior: return true iff the manipulation happened at or below the constraint path.
"""
function shouldschedule(::Solver, constraint::LocalConstraint, path::Vector{Int})::Bool
    return (length(path) >= length(constraint.path)) && (path[1:length(constraint.path)] == constraint.path)
end

