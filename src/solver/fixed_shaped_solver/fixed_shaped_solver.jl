"""
Representation of a branching constraint in the search tree.
"""
struct Branch
    hole::StateHole
    rule::Int
end

#Shared reference to an empty vector to reduce memory allocations.
NOBRANCHES = Vector{Branch}()

"""
A DFS solver that uses `StateHole`s.
"""
mutable struct UniformSolver <: Solver
    grammar::AbstractGrammar
    sm::StateManager
    tree::Union{RuleNode, StateHole}
    unvisited_branches::Stack{Vector{Branch}}
    path_to_node::Dict{Vector{Int}, AbstractRuleNode}
    node_to_path::Dict{AbstractRuleNode, Vector{Int}}
    isactive::Dict{AbstractLocalConstraint, StateInt}
    canceledconstraints::Set{AbstractLocalConstraint}
    nsolutions::Int
    isfeasible::Bool
    schedule::PriorityQueue{AbstractLocalConstraint, Int}
    fix_point_running::Bool
    statistics::Union{SolverStatistics, Nothing}
    derivation_heuristic
end


"""
    UniformSolver(grammar::AbstractGrammar, fixed_shaped_tree::AbstractRuleNode)
"""
function FixedShapedSolver(grammar::AbstractGrammar, fixed_shaped_tree::AbstractRuleNode; with_statistics=false, derivation_heuristic=nothing)
    @assert !contains_nonuniform_hole(fixed_shaped_tree) "$(fixed_shaped_tree) contains non-uniform holes"
    sm = StateManager()
    tree = StateHole(sm, fixed_shaped_tree)
    unvisited_branches = Stack{Vector{Branch}}()
    path_to_node = Dict{Vector{Int}, AbstractRuleNode}()
    node_to_path = Dict{AbstractRuleNode, Vector{Int}}()
    isactive = Dict{AbstractLocalConstraint, StateInt}()
    canceledconstraints = Set{AbstractLocalConstraint}()
    nsolutions = 0
    schedule = PriorityQueue{AbstractLocalConstraint, Int}()
    fix_point_running = false
    statistics = @match with_statistics begin
        ::SolverStatistics => with_statistics
        ::Bool => with_statistics ? SolverStatistics("UniformSolver") : nothing
        ::Nothing => nothing
    end
    if !isnothing(statistics) statistics.name = "FixedShapedSolver" end
    solver = FixedShapedSolver(grammar, sm, tree, unvisited_branches, path_to_node, node_to_path, isactive, canceledconstraints, nsolutions, true, schedule, fix_point_running, statistics, derivation_heuristic)
    notify_new_nodes(solver, tree, Vector{Int}())
    fix_point!(solver)
    if isfeasible(solver)
        save_state!(solver)
        push!(unvisited_branches, generate_branches(solver)) #generate initial branches for the root search node
    end
    return solver
end


"""
    notify_new_nodes(solver::UniformSolver, node::AbstractRuleNode, path::Vector{Int})

Notify all grammar constraints about the new `node` and its (grand)children
"""
function notify_new_nodes(solver::UniformSolver, node::AbstractRuleNode, path::Vector{Int})
    for (i, childnode) ∈ enumerate(get_children(node))
        notify_new_nodes(solver, childnode, push!(copy(path), i))
    end
    solver.path_to_node[path] = node
    solver.node_to_path[node] = path
    for c ∈ get_grammar(solver).constraints
        on_new_node(solver, c, path)
    end
end


"""
    get_path(solver::FixedShapedSolver, node::AbstractRuleNode)

Get the path at which the `node` is located.
"""
function HerbCore.get_path(solver::FixedShapedSolver, node::AbstractRuleNode)::Vector{Int}
    return solver.node_to_path[node]
end


"""
    get_node_at_location(solver::UniformSolver, path::Vector{Int})

Get the node that is located at the provided `path`.
"""
function HerbCore.get_node_at_location(solver::UniformSolver, path::Vector{Int})
    return solver.path_to_node[path]
end


"""
    get_hole_at_location(solver::UniformSolver, path::Vector{Int})

Get the hole that is located at the provided `path`.
"""
function get_hole_at_location(solver::UniformSolver, path::Vector{Int})
    hole = solver.path_to_node[path]
    @assert hole isa StateHole
    return hole
end


"""
    function get_grammar(solver::UniformSolver)::AbstractGrammar

Get the grammar.
"""
function get_grammar(solver::UniformSolver)::AbstractGrammar
    return solver.grammar
end


"""
    function get_tree(solver::UniformSolver)::AbstractRuleNode

Get the root of the tree. This remains the same instance throughout the entire search.
"""
function get_tree(solver::UniformSolver)::AbstractRuleNode
    return solver.tree
end


"""
    deactivate!(solver::FixedShapedSolver, constraint::AbstractLocalConstraint)

Function that should be called whenever the constraint is already satisfied and never has to be repropagated.
"""
function deactivate!(solver::FixedShapedSolver, constraint::AbstractLocalConstraint)
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
    post!(solver::FixedShapedSolver, constraint::AbstractLocalConstraint)

Post a new local constraint.
Converts the constraint to a state constraint and schedules it for propagation.
"""
function post!(solver::FixedShapedSolver, constraint::AbstractLocalConstraint)
    if !isfeasible(solver) return end
    # initial propagation of the new constraint
    propagate!(solver, constraint)
    if constraint ∈ solver.canceledconstraints
        # the constraint was deactivated during the initial propagation, cancel posting the constraint
        #TODO: reduce the amount of `post!` calls in the fixed shaped solver
        # See https://github.com/orgs/Herb-AI/projects/6/views/1?pane=issue&itemId=57401412
        track!(solver.statistics, "cancel post (2/2)")
        delete!(solver.canceledconstraints, constraint)
        return
    end
    #if the was not deactivated after initial propagation, it can be added to the list of constraints
    @assert constraint ∉ keys(solver.isactive) "Attempted to post a constraint that was already posted before"
    solver.isactive[constraint] = StateInt(solver.sm, 1)
end


"""
    notify_tree_manipulation(solver::UniformSolver, event_path::Vector{Int})

Notify subscribed constraints that a tree manipulation has occured at the `event_path` by scheduling them for propagation
"""
function notify_tree_manipulation(solver::UniformSolver, event_path::Vector{Int})
    if !isfeasible(solver) return end
    for (constraint, isactive) ∈ solver.isactive
        if get_value(isactive) == 1
            if shouldschedule(solver, constraint, event_path)
                schedule!(solver, constraint)
            end
        end
    end
end


"""
    isfeasible(solver::UniformSolver)

Returns true if no inconsistency has been detected.
"""
function isfeasible(solver::UniformSolver)
    return solver.isfeasible
end


"""
    mark_infeasible!(solver::Solver)

Function to be called if any inconsistency has been detected
"""
function mark_infeasible!(solver::UniformSolver)
    solver.isfeasible = false
end


"""
Save the current state of the solver, can restored using `restore!`
"""
function save_state!(solver::UniformSolver)
    @assert isfeasible(solver)
    track!(solver.statistics, "save_state!")
    save_state!(solver.sm)
end


"""
Restore state of the solver until the last `save_state!`
"""
function restore!(solver::UniformSolver)
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
function generate_branches(solver::UniformSolver)::Vector{Branch}
    #omitting `::Vector{Branch}` from `_dfs` speeds up the search by a factor of 2
    @assert isfeasible(solver)
    function _dfs(node::Union{StateHole, RuleNode}) #::Vector{Branch}
        if node isa StateHole && size(node.domain) > 1
            #use the derivation_heuristic if the parent_iterator is set up 
            if isnothing(solver.derivation_heuristic)
                return [Branch(node, rule) for rule ∈ node.domain]
            end
            return [Branch(node, rule) for rule ∈ solver.derivation_heuristic(findall(node.domain))]
        end
        for child ∈ node.children
            branches = _dfs(child)
            if !isempty(branches)
                return branches
            end
        end
        return NOBRANCHES
    end
    return _dfs(solver.tree)
end


"""
    next_solution!(solver::FixedShapedSolver)::Union{RuleNode, StateHole, Nothing}

Built-in iterator. Search for the next unvisited solution.
Returns nothing if all solutions have been found already.
"""
function next_solution!(solver::FixedShapedSolver)::Union{RuleNode, StateHole, Nothing}
    if solver.nsolutions == 1000000 @warn "FixedShapedSolver is iterating over more than 1000000 solutions..." end
    if solver.nsolutions > 0
        # backtrack from the previous solution
        restore!(solver)
    end
    while length(solver.unvisited_branches) > 0
        branches = first(solver.unvisited_branches)
        if length(branches) > 0
            # current depth has unvisted branches, pick a branch to explore
            branch = pop!(branches)
            save_state!(solver)
            remove_all_but!(solver, solver.node_to_path[branch.hole], branch.rule)
            if isfeasible(solver)
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
    if solver.nsolutions == 0 && isfeasible(solver)
        _isfilledrecursive(node) = isfilled(node) && all(_isfilledrecursive(c) for c ∈ node.children)
        if _isfilledrecursive(solver.tree)
            # search node is the root and the only solution, return the solution (edgecase)
            solver.nsolutions += 1
            track!(solver.statistics, "#CompleteTrees")
            return solver.tree
        end
    end
    return nothing
end


"""
    count_solutions(solver::UniformSolver)

Iterate over all solutions and count the number of solutions encountered.
!!! warning:
    Solutions are overwritten. It is not possible to return all the solutions without copying. 
"""
function count_solutions(solver::UniformSolver)
    count = 0
    s = next_solution!(solver)
    while !isnothing(s)
        count += 1
        s = next_solution!(solver)
    end
    return count
end
