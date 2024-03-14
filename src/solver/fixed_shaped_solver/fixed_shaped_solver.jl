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
    constraints::Vector{Constraint}
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
    constraints = Vector{Constraint}()
    nsolutions = 0
    isfeasible = true
    schedule = PriorityQueue{Constraint, Int}()
    fix_point_running = false
    statistics = with_statistics ? SolverStatistics() : nothing
    solver = FixedShapedSolver(grammar, sm, tree, unvisited_branches, path_to_node, node_to_path, constraints, nsolutions, isfeasible, schedule, fix_point_running, statistics)
    notify_new_nodes(solver, tree, Vector{Int}())
    save_state!(solver)
    push!(unvisited_branches, generate_branches(solver)) #generate initial branches for the root search node
    return solver
end


"""
    notify_new_nodes(node::AbstractRuleNode, path::Vector{Int})

Notify all grammar constraints about the `node` and its (grand)children
"""
function notify_new_nodes(solver::FixedShapedSolver, node::AbstractRuleNode, path::Vector{Int})
    solver.path_to_node[path] = node
    solver.node_to_path[node] = path
    for c ∈ get_grammar(solver).constraints
        on_new_node(solver, c, path)
    end
    for (i, childnode) ∈ enumerate(get_children(node))
        notify_new_nodes(solver, childnode, push!(copy(path), i))
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
    post!(solver::FixedShapedSolver, constraint::Constraint)

Post a new local constraint.
Converts the constraint to a state constraint and schedules it for propagation.
"""
function post!(solver::FixedShapedSolver, constraint::Constraint)
    #sc = StateConstraint(constraint, make_state_int(solver.sm, 1))
    sc = constraint
    push!(solver.constraints, sc)
    schedule!(solver, sc)
end


"""
    propagate_on_tree_manipulation!(solver::FixedShapedSolver, constraint::Constraint)
"""
function propagate_on_tree_manipulation!(solver::FixedShapedSolver, constraint::Constraint, path::Vector{Int})
    #TODO: find related state constraint and set isactive=true
    ()
end

"""
    notify_tree_manipulation(solver::FixedShapedSolver, event_path::Vector{Int})

Notify subscribed constraints that a tree manipulation has occured at the `event_path` by scheduling them for propagation
"""
function notify_tree_manipulation(solver::FixedShapedSolver, event_path::Vector{Int})
    if !is_feasible(solver) return end
    #TODO: event_path is ignored.
    #initial version: schedule all constraints
    for c ∈ solver.constraints
        schedule!(solver, c)
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
    mark_infeasible(solver::Solver)

Function to be called if any inconsistency has been detected
"""
function mark_infeasible(solver::FixedShapedSolver)
    solver.isfeasible = false
end


"""
Save the current state of the solver, can restored using `restore!`
"""
function save_state!(solver::FixedShapedSolver)
    save_state!(solver.sm)
end


"""
Restore state of the solver until the last `save_state!`
"""
function restore!(solver::FixedShapedSolver)
    restore!(solver.sm)
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
    next_solution!(solver::FixedShapedSolver)

Built-in iterator. Search for the next unvisited solution.
Returns nothing if all solutions have been found already.
"""
function next_solution!(solver::FixedShapedSolver)::Union{AbstractRuleNode, Nothing}
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
            remove_all_but!(branch.hole.domain, branch.rule)
            #TODO: fix point and schedule inside the remove_all_but!
            notify_tree_manipulation(solver, Vector{Int}())
            fix_point!(solver)
            if is_feasible(solver)
                # generate new branches for the new search node
                branches = generate_branches(solver)
                if length(branches) == 0
                    # search node is a solution leaf node, return the solution
                    solver.nsolutions += 1
                    return solver.tree
                else
                    # search node is an internal node, store the branches to visit
                    push!(solver.unvisited_branches, branches)
                end
            else
                # search node is an infeasible leaf node, backtrack
                restore!(solver)
            end
        else
            # search node is an exhausted internal node, backtrack
            restore!(solver)
            pop!(solver.unvisited_branches)
        end
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
