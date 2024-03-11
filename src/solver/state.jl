"""
    mutable struct State 

A state to be solved by the constraint [`Solver`](@ref).
A state contains of:

- `tree`: A partial AST
- `on_tree_manipulation`: The local constraints that apply to this tree. 
   These constraints are enforced each time the tree is modified.
- `isfeasible`: Flag to indicate if this state is still feasible.
   When a propagator spots an inconsistency, this field will be set to false.
   Tree manipulations and further propagations are not allowed on infeasible states
"""
mutable struct State
    tree::AbstractRuleNode
    on_tree_manipulation::Dict{Vector{Int}, Set{Constraint}}
    isfeasible::Bool
end

State(tree::AbstractRuleNode) = State(tree, Dict{Vector{Int64}, Constraint}(), true)

function Base.copy(state::State) 
    tree = deepcopy(state.tree)
    on_tree_manipulation = Dict{Vector{Int}, Set{Constraint}}()
    for (path, set) ∈ state.on_tree_manipulation
        on_tree_manipulation[path] = copy(set)
    end
    State(tree, on_tree_manipulation, state.isfeasible)
end

#TODO: replace `on_tree_manipulation` with a better data structure
