"""
Representation of a branching constraint in the search tree.
"""
struct Branch
    hole::StateFixedShapedHole
    rule::Int
end


"""
A DFS solver that uses `StateFixedShapedHole`s.
"""
mutable struct FixedShapedSolver <: Solver
    grammar::Grammar
    sm::StateManager
    tree::Union{RuleNode, StateFixedShapedHole}
    unvisited_branches::Stack{Vector{Branch}}
    path_to_node::Dict{Vector{Int}, AbstractRuleNode}
    node_to_path::Dict{AbstractRuleNode, Vector{Int}}
    isactive::Dict{Constraint, StateInt}
    canceledconstraints::Set{Constraint}
    nsolutions::Int
    isfeasible::Bool
    schedule::PriorityQueue{Constraint, Int}
    fix_point_running::Bool
    statistics::Union{SolverStatistics, Nothing}
end


"""
    FixedShapedSolver(grammar::Grammar, fixed_shaped_tree::AbstractRuleNode)
"""
function FixedShapedSolver(grammar::Grammar, fixed_shaped_tree::AbstractRuleNode; with_statistics=false)
    @assert !contains_variable_shaped_hole(fixed_shaped_tree) "$(fixed_shaped_tree) contains variable shaped holes"
    sm = StateManager()
    tree = StateFixedShapedHole(sm, fixed_shaped_tree)
    unvisited_branches = Stack{Vector{Branch}}()
    path_to_node = Dict{Vector{Int}, AbstractRuleNode}()
    node_to_path = Dict{AbstractRuleNode, Vector{Int}}()
    isactive = Dict{Constraint, StateInt}()
    canceledconstraints = Set{Constraint}()
    nsolutions = 0
    isfeasible = true
    schedule = PriorityQueue{Constraint, Int}()
    fix_point_running = false
    statistics = @match with_statistics begin
        ::SolverStatistics => with_statistics
        ::Bool => with_statistics ? SolverStatistics("FixedShapedSolver") : nothing
        ::Nothing => nothing
    end
    if !isnothing(statistics) statistics.name = "FixedShapedSolver" end
    solver = FixedShapedSolver(grammar, sm, tree, unvisited_branches, path_to_node, node_to_path, isactive, canceledconstraints, nsolutions, isfeasible, schedule, fix_point_running, statistics)
    notify_new_nodes(solver, tree, Vector{Int}())
    fix_point!(solver)
    if is_feasible(solver)
        save_state!(solver)
        push!(unvisited_branches, generate_branches(solver)) #generate initial branches for the root search node
    end
    return solver
end


"""
    notify_new_nodes(node::AbstractRuleNode, path::Vector{Int})

Notify all grammar constraints about the `node` and its (grand)children
"""
function notify_new_nodes(solver::FixedShapedSolver, node::AbstractRuleNode, path::Vector{Int})
    for (i, childnode) ∈ enumerate(get_children(node))
        notify_new_nodes(solver, childnode, push!(copy(path), i))
    end
    solver.path_to_node[path] = node
    solver.node_to_path[node] = path
    for c ∈ get_grammar(solver).constraints
        on_new_node(solver, c, path)
    end
end

function HerbCore.get_node_path(solver::FixedShapedSolver, node::AbstractRuleNode)
    return solver.node_to_path[node]
end

function HerbCore.get_node_at_location(solver::FixedShapedSolver, path::Vector{Int})
    return solver.path_to_node[path]
end

function get_hole_at_location(solver::FixedShapedSolver, path::Vector{Int})
    hole = solver.path_to_node[path]
    @assert hole isa Hole
    return hole
end

function get_grammar(solver::FixedShapedSolver)::Grammar
    return solver.grammar
end

function get_tree(solver::FixedShapedSolver)::AbstractRuleNode
    return solver.tree
end


"""
    deactivate!(solver::FixedShapedSolver, constraint::Constraint)

Function that should be called whenever the constraint is already satisfied and never has to be repropagated.
"""
function deactivate!(solver::FixedShapedSolver, constraint::Constraint)
    if constraint ∈ keys(solver.schedule)
        # remove the constraint from the schedule
        track!(solver.statistics, "deactivate! removed from schedule")
        delete!(solver.schedule, constraint)
    end
    if constraint ∈ keys(solver.isactive)
        # the constraint was posted earlier and should be deactivated
        set_value!(solver.isactive[constraint], 0)
        return
    end
    # the constraint is satisfied during its initial propagation
    # the constraint was not posted yet, the post should be canceled
    track!(solver.statistics, "cancel post (1/2)")
    push!(solver.canceledconstraints, constraint)
end


"""
    post!(solver::FixedShapedSolver, constraint::Constraint)

Post a new local constraint.
Converts the constraint to a state constraint and schedules it for propagation.
"""
function post!(solver::FixedShapedSolver, constraint::Constraint)
    if !is_feasible(solver) return end
    # initial propagation of the new constraint
    propagate!(solver, constraint)
    if constraint ∈ solver.canceledconstraints
        # the constraint was deactivated during the initial propagation, cancel posting the constraint
        track!(solver.statistics, "cancel post (2/2)")
        delete!(solver.canceledconstraints, constraint)
        return
    end
    #if the was not deactivated after initial propagation, it can be added to the list of constraints
    @assert constraint ∉ keys(solver.isactive) "Attempted to post a constraint that was already posted before"
    solver.isactive[constraint] = make_state_int(solver.sm, 1)
end


"""
    notify_tree_manipulation(solver::FixedShapedSolver, event_path::Vector{Int})

Notify subscribed constraints that a tree manipulation has occured at the `event_path` by scheduling them for propagation
"""
function notify_tree_manipulation(solver::FixedShapedSolver, event_path::Vector{Int})
    if !is_feasible(solver) return end
    for (constraint, isactive) ∈ solver.isactive
        if get_value(isactive) == 1
            if shouldschedule(solver, constraint, event_path)
                schedule!(solver, constraint)
            end
        end
    end
end


:"""
    is_feasible(solver::FixedShapedSolver)

Returns true if no inconsistency has been detected.
"""
function is_feasible(solver::FixedShapedSolver)
    return solver.isfeasible
end


"""
    mark_infeasible!(solver::Solver)

Function to be called if any inconsistency has been detected
"""
function mark_infeasible!(solver::FixedShapedSolver)
    solver.isfeasible = false
end


"""
Save the current state of the solver, can restored using `restore!`
"""
function save_state!(solver::FixedShapedSolver)
    @assert is_feasible(solver)
    track!(solver.statistics, "save_state!")
    save_state!(solver.sm)
end


"""
Restore state of the solver until the last `save_state!`
"""
function restore!(solver::FixedShapedSolver)
    track!(solver.statistics, "restore!")
    restore!(solver.sm)
    solver.isfeasible = true
end

#TODO: implement more branching schemes
"""
Returns a vector of disjoint branches to expand the search tree at its current state.
Example:
```
# pseudo code
Hole(domain=[2, 4, 5], children=[
    Hole(domain=[1, 6]), 
    Hole(domain=[1, 6])
])
```
A possible branching scheme could be to be split up in three `Branch`ing constraints:
- `Branch(firsthole, 2)`
- `Branch(firsthole, 4)`
- `Branch(firsthole, 5)`
"""
function generate_branches(solver::FixedShapedSolver)::Vector{Branch}
    #omitting `::Vector{Branch}` from `_dfs` speeds up the search by a factor of 2
    @assert is_feasible(solver)
    function _dfs(node::Union{StateFixedShapedHole, RuleNode}) #::Vector{Branch}
        if node isa StateFixedShapedHole && size(node.domain) > 1
            return [Branch(node, rule) for rule ∈ node.domain]
        end
        for child ∈ node.children
            branches = _dfs(child)
            if !isempty(branches)
                return branches
            end
        end
        return []
    end
    return _dfs(solver.tree)
end


"""
    next_solution!(solver::FixedShapedSolver)::Union{RuleNode, StateFixedShapedHole, Nothing}

Built-in iterator. Search for the next unvisited solution.
Returns nothing if all solutions have been found already.
"""
function next_solution!(solver::FixedShapedSolver)::Union{RuleNode, StateFixedShapedHole, Nothing}
    if solver.nsolutions == 1000000 @warn "FixedShapedSolver is iterating over more than 1000000 solutions..." end
    if solver.nsolutions > 0
        # backtrack from the previous solution
        restore!(solver)
    end
    while length(solver.unvisited_branches) > 0
        branches = top(solver.unvisited_branches)
        if length(branches) > 0
            # current depth has unvisted branches, pick a branch to explore
            branch = pop!(branches)
            save_state!(solver)
            remove_all_but!(solver, solver.node_to_path[branch.hole], branch.rule)
            if is_feasible(solver)
                # generate new branches for the new search node
                branches = generate_branches(solver)
                if length(branches) == 0
                    # search node is a solution leaf node, return the solution
                    solver.nsolutions += 1
                    track!(solver.statistics, "#CompleteTrees")
                    return solver.tree
                else
                    # search node is an (non-root) internal node, store the branches to visit
                    track!(solver.statistics, "#InternalSearchNodes")
                    push!(solver.unvisited_branches, branches)
                end
            else
                # search node is an infeasible leaf node, backtrack
                track!(solver.statistics, "#InfeasibleTrees")
                restore!(solver)
            end
        else
            # search node is an exhausted internal node, backtrack
            restore!(solver)
            pop!(solver.unvisited_branches)
        end
    end
    if solver.nsolutions == 0 && is_feasible(solver)
        # search node is the root and the only solution, return the solution (edgecase)
        solver.nsolutions += 1
        track!(solver.statistics, "#CompleteTrees")
        return solver.tree
    end
    return nothing
end


"""
    count_solutions(solver::FixedShapedSolver)

Iterate over all solutions and count the number of solutions encountered.
!!! warning:
    Solutions are overwritten. It is not possible to return all the solutions without copying. 
"""
function count_solutions(solver::FixedShapedSolver)
    count = 0
    s = next_solution!(solver)
    while !isnothing(s)
        count += 1
        s = next_solution!(solver)
    end
    return count
end
