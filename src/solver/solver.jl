"""
    Solver

Maintains a feasible partial program in a [`State`](@ref). A [`ProgramIterator`](@ref) may manipulate the partial tree with the following functions:
- `remove!`
- `substitute!`
- `fill!`
"""
mutable struct Solver
    grammar::Grammar
    state::Union{State, Nothing}
    schedule::PriorityQueue{Constraint, Int}
    statistics::Union{SolverStatistics, Nothing}
end

"""
    Solver(grammar::Grammar)

Constructs a new solver, with an initial state using starting symbol `sym`
"""
function Solver(grammar::Grammar, sym::Symbol; with_statistics=false)
    stats = with_statistics ? SolverStatistics() : nothing
    solver = Solver(grammar, nothing, PriorityQueue{Constraint, Int}(), stats)
    init_node = Hole(get_domain(grammar, sym))
    new_state!(solver, init_node)
    return solver
end


"""
    schedule(solver::Solver, constraint::Constraint)

Schedules the `constraint` for propagation
"""
function schedule!(solver::Solver, constraint::Constraint)
    if constraint ∉ keys(solver.schedule)
        enqueue!(solver.schedule, constraint, 99) #TODO: replace `99` with `get_priority(c)`
    end
end

"""
    fix_point!(solver::Solver)

Propagate constraints in the current state until no further dedecutions can be made
"""
function fix_point!(solver::Solver)
    while !isempty(solver.schedule)
        if !is_feasible(solver)
            #an inconsistency was found, stop propagating constraints and return
            empty!(solver.schedule)
            return
        end
        constraint = dequeue!(solver.schedule) 
        propagate!(solver, constraint)
    end
end

"""
    new_state!(solver::Solver, tree::AbstractRuleNode)

Overwrites the current state and propagates constraints on the `tree` from the ground up
"""
function new_state!(solver::Solver, tree::AbstractRuleNode)
    #TODO: rebuild the tree node by node, to add local constraints correctly
    solver.state = State(tree, length(tree), Dict{Vector{Int64}, Constraint}(), true)
    notify_new_node(solver, Vector{Int}()) #notify about the root node
    fix_point!(solver)
end

"""
    save_state!(solver::Solver)

Returns a copy of the current state that can be restored by calling `load_state!(solver, state)`
"""
function save_state!(solver::Solver)::State
    track!(solver.statistics, "save_state!")
    return copy(get_state(solver))
end

"""
    load_state!(solver::Solver, state::State)

Overwrites the current state with the given `state`
"""
function load_state!(solver::Solver, state::State)
    empty!(solver.schedule)
    solver.state = state
end

function get_tree(solver::Solver)::AbstractRuleNode
    return solver.state.tree
end

function get_grammar(solver::Solver)::Grammar
    return solver.grammar
end

function get_state(solver::Solver)::State
    return solver.state
end

function mark_infeasible(solver::Solver)
    #TODO: immediately delete the state and set the current state to nothing
    solver.state.isfeasible = false
end

function is_feasible(solver::Solver)
    return get_state(solver).isfeasible
end

#TODO: remove the scope of `HerbCore`?
function HerbCore.get_node_at_location(solver::Solver, location::Vector{Int})::AbstractRuleNode
    # dispatches the function on type `AbstractRuleNode` (defined in rulenode_operator.jl in HerbGrammar.jl)
    node = get_node_at_location(get_tree(solver), location)
    @assert !isnothing(node) "No node exists at location $location in the current state of the solver"
    return node
end

function get_hole_at_location(solver::Solver, location::Vector{Int})::Hole
    hole = get_node_at_location(get_tree(solver), location)
    @assert hole isa Hole "Hole $hole is of non-Hole type $(typeof(hole)). Tree: $(get_tree(solver)), location: $(location)"
    return hole
end


"""
    propagate_on_tree_manipulation!(solver::Solver, c::Constraint)

The `constraint` will be propagated on the next tree manipulation
"""
function propagate_on_tree_manipulation!(solver::Solver, constraint::Constraint, event_path::Vector{Int})
    #TODO: propagate only on specific tree manipulation. (e.g. at exactly the given event_path, or below the given event_path)
    dict = get_state(solver).on_tree_manipulation
    if event_path ∉ keys(dict)
        dict[event_path] = Set{Constraint}()
    end
    push!(dict[event_path], constraint)
end


"""
    notify_tree_manipulation(solver::Solver, event_path::Vector{Int})

Notify subscribed constraints that a tree manipulation has occured at the `event_path` by scheduling them for propagation
"""
function notify_tree_manipulation(solver::Solver, event_path::Vector{Int})
    #TODO: keep track of the notify lists on the holes themselves
    #TODO: propagate only on specific tree manipulation. (e.g. at exactly the given event_path, or above the given event_path)
    # Propagate all constraints in lists at or above the event_path
    event_path = push!(copy(event_path), 0)
    while !isempty(event_path)
        pop!(event_path)
        dict = get_state(solver).on_tree_manipulation
        if event_path ∈ keys(dict)
            for c ∈ dict[event_path]
                schedule!(solver, c)
            end
            empty!(dict[event_path])
        end
    end
    # Always propagate all constraints:
    # dict = get_state(solver).on_tree_manipulation
    # for event_path ∈ keys(dict)
    #     for c ∈ dict[event_path]
    #         schedule!(solver, c)
    #     end
    #     empty!(dict[event_path])
    # end
end

"""
    notify_new_node(solver::Solver, event_path::Vector{Int})

Notify subscribed constraints that a new node has appeared at the `event_path` by calling their respective `on_new_node` function
"""
function notify_new_node(solver::Solver, event_path::Vector{Int})
    for c ∈ get_grammar(solver).constraints
        on_new_node(solver, c, event_path)
    end
end
