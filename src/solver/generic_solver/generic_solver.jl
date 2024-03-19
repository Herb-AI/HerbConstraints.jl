"""
    GenericSolver

Maintains a feasible partial program in a [`State`](@ref). A [`ProgramIterator`](@ref) may manipulate the partial tree with the following functions:
- `remove!`
- `substitute!`
- `fill!`
"""
mutable struct GenericSolver <: Solver
    grammar::Grammar
    state::Union{State, Nothing}
    schedule::PriorityQueue{Constraint, Int}
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
    solver = GenericSolver(grammar, nothing, PriorityQueue{Constraint, Int}(), stats, use_fixedshapedsolver, false, typemax(Int), typemax(Int))
    new_state!(solver, init_node)
    return solver
end


"""
    deactivate!(solver::GenericSolver, constraint::Constraint)

Function that should be called whenever the constraint is already satisfied and never has to be repropagated.
"""
function deactivate!(solver::GenericSolver, constraint::Constraint)
    #TODO: refactor constraint deactivation for the GenericSolver. 
    # Currently, constraints are deleted by default, so `deactivate!` can be ignored
    ()
end


"""
    post!(solver::GenericSolver, constraint::Constraint)

Imposes the `constraint` to the current state.
By default, the constraint will be scheduled for its initial propagation.
Constraints can overload this method to add themselves to notify lists or triggers.
"""
function post!(solver::GenericSolver, constraint::Constraint)
    track!(solver.statistics, "post! $(typeof(constraint))")
    schedule!(solver, constraint)
end


"""
    new_state!(solver::GenericSolver, tree::AbstractRuleNode)

Overwrites the current state and propagates constraints on the `tree` from the ground up
"""
function new_state!(solver::GenericSolver, tree::AbstractRuleNode)
    track!(solver.statistics, "new_state!")
    solver.state = State(tree)
    function _dfs_notify(node::AbstractRuleNode, path::Vector{Int})
        notify_new_node(solver, path)
        for (i, childnode) ∈ enumerate(get_children(node))
            _dfs_notify(childnode, push!(copy(path), i))
        end
    end
    function _dfs_simplify(node::AbstractRuleNode, path::Vector{Int})
        if (node isa Hole)
            simplify_hole!(solver, path)
        end
        for (i, childnode) ∈ enumerate(get_children(node))
            _dfs_simplify(childnode, push!(copy(path), i))
        end
    end
    _dfs_notify(tree, Vector{Int}()) #notify the constraints about all nodes in the new state
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
    mark_infeasible(solver::GenericSolver)

Function to be called if any inconsistency has been detected
"""
function mark_infeasible(solver::GenericSolver)
    #TODO: immediately delete the state and set the current state to nothing
    solver.state.isfeasible = false
end

"""
    is_feasible(solver::GenericSolver)

Returns true if no inconsistency has been detected. Used in several ways:
- Iterators should check for infeasibility to discard infeasible states
- After any tree manipulation with the possibility of an inconsistency (e.g. `remove_below!`, `remove_above!`, `remove!`)
- `fix_point!` should check for infeasibility to clear its schedule and return
- Some `GenericSolver` functions assert a feasible state for debugging purposes `@assert is_feasible(solver)`
- Some `GenericSolver` functions have a guard that skip the function on an infeasible state: `if !is_feasible(solver) return end`
"""
function is_feasible(solver::GenericSolver)
    return get_state(solver).isfeasible
end

#TODO: remove the scope of `HerbCore`?
function HerbCore.get_node_at_location(solver::GenericSolver, location::Vector{Int})::AbstractRuleNode
    # dispatches the function on type `AbstractRuleNode` (defined in rulenode_operator.jl in HerbGrammar.jl)
    node = get_node_at_location(get_tree(solver), location)
    @assert !isnothing(node) "No node exists at location $location in the current state of the solver"
    return node
end

function get_hole_at_location(solver::GenericSolver, location::Vector{Int})::Hole
    hole = get_node_at_location(get_tree(solver), location)
    @assert hole isa Hole "Hole $hole is of non-Hole type $(typeof(hole)). Tree: $(get_tree(solver)), location: $(location)"
    return hole
end


"""
    propagate_on_tree_manipulation!(solver::GenericSolver, constraint::Constraint, event_path::Vector{Int})

The `constraint` will be propagated on the next tree manipulation at or above the `event_path`
"""
function propagate_on_tree_manipulation!(solver::GenericSolver, constraint::Constraint, event_path::Vector{Int})
    @assert is_feasible(solver)
    push!(get_state(solver).activeconstraints, constraint)
end


"""
    notify_tree_manipulation(solver::GenericSolver, event_path::Vector{Int})

Notify subscribed constraints that a tree manipulation has occured at the `event_path` by scheduling them for propagation
"""
function notify_tree_manipulation(solver::GenericSolver, event_path::Vector{Int})
    if !is_feasible(solver) return end
    activeconstraints = get_state(solver).activeconstraints
    for c ∈ activeconstraints
        if shouldschedule(solver, c, event_path)
            schedule!(solver, c)
            delete!(activeconstraints, c)  #by default, scheduled constraints are deleted
        end
    end
end

"""
    notify_new_node(solver::GenericSolver, event_path::Vector{Int})

Notify subscribed constraints that a new node has appeared at the `event_path` by calling their respective `on_new_node` function
"""
function notify_new_node(solver::GenericSolver, event_path::Vector{Int})
    if !is_feasible(solver) return end
    for c ∈ get_grammar(solver).constraints
        on_new_node(solver, c, event_path)
    end
end
