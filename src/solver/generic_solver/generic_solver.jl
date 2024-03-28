"""
    GenericSolver

Maintains a feasible partial program in a [`State`](@ref). A [`ProgramIterator`](@ref) may manipulate the partial tree with the following tree manipulations:
- `substitute!`
- `remove!`
- `remove_below!`
- `remove_above!`
- `remove_all_but!`

Each [`State`](@ref) holds an independent propagation program. Program iterators can freely move back and forth between states using:
- `new_state!`
- `save_state!`
- `load_state!`
"""
mutable struct GenericSolver <: Solver
    grammar::Grammar
    state::Union{State, Nothing}
    schedule::PriorityQueue{LocalConstraint, Int}
    statistics::Union{SolverStatistics, Nothing}
    use_fixedshapedsolver::Bool
    fix_point_running::Bool
    max_size::Int
    max_depth::Int
end


"""
    GenericSolver(grammar::Grammar, sym::Symbol)

Constructs a new solver, with an initial state using starting symbol `sym`
"""
function GenericSolver(grammar::Grammar, sym::Symbol; with_statistics=false, use_fixedshapedsolver=true)
    init_node = Hole(get_domain(grammar, sym))
    GenericSolver(grammar, init_node, with_statistics=with_statistics, use_fixedshapedsolver=use_fixedshapedsolver)
end


"""
    GenericSolver(grammar::Grammar, init_node::AbstractRuleNode)

Constructs a new solver, with an initial state of the provided [`AbstractRuleNode`](@ref).
"""
function GenericSolver(grammar::Grammar, init_node::AbstractRuleNode; with_statistics=false, use_fixedshapedsolver=true)
    stats = with_statistics ? SolverStatistics("GenericSolver") : nothing
    solver = GenericSolver(grammar, nothing, PriorityQueue{LocalConstraint, Int}(), stats, use_fixedshapedsolver, false, typemax(Int), typemax(Int))
    new_state!(solver, init_node)
    return solver
end


"""
    deactivate!(solver::GenericSolver, constraint::LocalConstraint)

Function that should be called whenever the constraint is already satisfied and never has to be repropagated.
"""
function deactivate!(solver::GenericSolver, constraint::LocalConstraint)
    if constraint ∈ keys(solver.schedule)
        # remove the constraint from the schedule
        track!(solver.statistics, "deactivate! removed from schedule")
        delete!(solver.schedule, constraint)
    end
    if constraint ∉ get_state(solver).active_constraints
        #TODO: make sure this code branch is never reached
        # a deactivated constraint was propagated again and deactivated again...
        track!(solver.statistics, "deactivate! (unnecessary)")
        # @assert constraint ∈ get_state(solver).active_constraints "Attempted to deactivate a deactivated constraint $(constraint)"
        # This assertion error can occur if a `propagate!` function is called outside `fix_point!`
        # For example, assume that `propagate!` function is called from `post!`
        # Consider the following call stack:
        # -----------------------------------------
        #   | post!                                 # a new constraint is posted
        #       | propagate!                        # the new constraint is propagated
        #           | remove!                       # the new constraint caused the removal of rule
        #               | notify_tree_manipulation  # the new constraint is scheduled for propagation
        #               | fix_point!                # scheduled constraints are propagated
        #                   | propagate!            # the new constraint is propagated
        #                       | deactivate!       # the new constraint is satisfied and deactivated itself
        #           | deactivate!                   # the new constraint is satisfied and deactivated itself (again)
        # -----------------------------------------
        # To prevent this scenario, initial propagations are scheduled, not propagated.
        # The expected behavior is as follows:
        # -----------------------------------------
        #   | post!                                 # a new constraint is posted
        #       | schedule!                         # the new constraint is scheduled for propagation
        #   | fix_point!                            # scheduled constraints are propagated
        #       | propagate!                        # the new constraint is propagated
        #           | remove!                       # the new constraint caused the removal of rule
        #               | notify_tree_manipulation  # the new constraint is scheduled for propagation
        #               | fix_point!                # nested fix point calls are ignored (see: `fix_point_running`)
        #           | deactivate!                   # the new constraint is satisfied, deactivated itself and removed itself from the schedule
        # -----------------------------------------
    end
    delete!(get_state(solver).active_constraints, constraint)
end


"""
    post!(solver::GenericSolver, constraint::LocalConstraint)

Imposes the `constraint` to the current state.
By default, the constraint will be scheduled for its initial propagation.
Constraints can overload this method to add themselves to notify lists or triggers.
"""
function post!(solver::GenericSolver, constraint::LocalConstraint)
    if !isfeasible(solver) return end
    track!(solver.statistics, "post! $(typeof(constraint))")
    # add to the list of active constraints
    push!(get_state(solver).active_constraints, constraint)
    # initial propagation of the new constraint
    propagate!(solver, constraint)
end


"""
    new_state!(solver::GenericSolver, tree::AbstractRuleNode)

Overwrites the current state and propagates constraints on the `tree` from the ground up
"""
function new_state!(solver::GenericSolver, tree::AbstractRuleNode)
    track!(solver.statistics, "new_state!")
    empty!(solver.schedule)
    solver.state = State(tree)
    function _dfs_simplify(node::AbstractRuleNode, path::Vector{Int})
        if (node isa Hole)
            simplify_hole!(solver, path)
        end
        for (i, childnode) ∈ enumerate(get_children(node))
            _dfs_simplify(childnode, push!(copy(path), i))
        end
    end
    notify_new_nodes(solver, tree, Vector{Int}()) #notify the grammar constraints about all nodes in the new state
    _dfs_simplify(tree, Vector{Int}()) #try to simplify all holes in the new state
    fix_point!(solver)
end

"""
    save_state!(solver::GenericSolver)

Returns a copy of the current state that can be restored by calling `load_state!(solver, state)`
"""
function save_state!(solver::GenericSolver)::State
    track!(solver.statistics, "save_state!")
    return copy(get_state(solver))
end

"""
    load_state!(solver::GenericSolver, state::State)

Overwrites the current state with the given `state`
"""
function load_state!(solver::GenericSolver, state::State)
    empty!(solver.schedule)
    solver.state = state
end

function get_tree_size(solver::GenericSolver)::Int
    #TODO: potential optimization: precompute/cache the size of the tree
    return length(get_tree(solver))
end

function get_tree(solver::GenericSolver)::AbstractRuleNode
    return solver.state.tree
end

function get_grammar(solver::GenericSolver)::Grammar
    return solver.grammar
end

function get_state(solver::GenericSolver)::State
    return solver.state
end

function get_max_depth(solver::GenericSolver)
    return solver.max_depth
end

function get_max_size(solver::GenericSolver)
    return solver.max_size
end


"""
    mark_infeasible!(solver::GenericSolver)

Function to be called if any inconsistency has been detected
"""
function mark_infeasible!(solver::GenericSolver)
    #TODO: immediately delete the state and set the current state to nothing
    solver.state.isfeasible = false
end

"""
    isfeasible(solver::GenericSolver)

Returns true if no inconsistency has been detected. Used in several ways:
- Iterators should check for infeasibility to discard infeasible states
- After any tree manipulation with the possibility of an inconsistency (e.g. `remove_below!`, `remove_above!`, `remove!`)
- `fix_point!` should check for infeasibility to clear its schedule and return
- Some `GenericSolver` functions assert a feasible state for debugging purposes `@assert isfeasible(solver)`
- Some `GenericSolver` functions have a guard that skip the function on an infeasible state: `if !isfeasible(solver) return end`
"""
function isfeasible(solver::GenericSolver)
    return get_state(solver).isfeasible
end


"""
    HerbCore.get_node_at_location(solver::GenericSolver, location::Vector{Int})::AbstractRuleNode

Get the node at path `location`.
"""
function HerbCore.get_node_at_location(solver::GenericSolver, location::Vector{Int})::AbstractRuleNode
    # dispatches the function on type `AbstractRuleNode` (defined in rulenode_operator.jl in HerbGrammar.jl)
    node = get_node_at_location(get_tree(solver), location)
    @assert !isnothing(node) "No node exists at location $location in the current state of the solver"
    return node
end

"""
    get_hole_at_location(solver::GenericSolver, location::Vector{Int})::Hole

Get the node at path `location` and assert it is a [`Hole`](@ref).
"""
function get_hole_at_location(solver::GenericSolver, location::Vector{Int})::Hole
    hole = get_node_at_location(get_tree(solver), location)
    @assert hole isa Hole "Hole $hole is of non-Hole type $(typeof(hole)). Tree: $(get_tree(solver)), location: $(location)"
    return hole
end


"""
    notify_tree_manipulation(solver::GenericSolver, event_path::Vector{Int})

Notify subscribed constraints that a tree manipulation has occured at the `event_path` by scheduling them for propagation
"""
function notify_tree_manipulation(solver::GenericSolver, event_path::Vector{Int})
    if !isfeasible(solver) return end
    active_constraints = get_state(solver).active_constraints
    for c ∈ active_constraints
        if shouldschedule(solver, c, event_path)
            schedule!(solver, c)
        end
    end
end


"""
    notify_new_node(solver::GenericSolver, event_path::Vector{Int})

Notify all constraints that a new node has appeared at the `event_path` by calling their respective `on_new_node` function.
!!! warning
    This does not notify the solver about nodes below the `event_path`. In that case, call [`notify_new_nodes`](@ref) instead.
"""
function notify_new_node(solver::GenericSolver, event_path::Vector{Int})
    if !isfeasible(solver) return end
    for c ∈ get_grammar(solver).constraints
        on_new_node(solver, c, event_path)
    end
end


"""
    notify_new_nodes(solver::GenericSolver, node::AbstractRuleNode, path::Vector{Int})

Notify all grammar constraints about the new `node` and its (grand)children
"""
function notify_new_nodes(solver::GenericSolver, node::AbstractRuleNode, path::Vector{Int})
    notify_new_node(solver, path)
    for (i, childnode) ∈ enumerate(get_children(node))
        notify_new_nodes(solver, childnode, push!(copy(path), i))
    end
end