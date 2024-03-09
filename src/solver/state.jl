"""
    mutable struct State 

A state to be solved by the constraint [`Solver`](@ref).
A state contains of:

- `tree`: A partial AST
- `size`: The size of the tree. This is a cached value which prevents
   having to traverse the entire tree each time the size is needed.
- `constraints`: The local constraints that apply to this tree. 
   These constraints are enforced each time the tree is modified.
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

