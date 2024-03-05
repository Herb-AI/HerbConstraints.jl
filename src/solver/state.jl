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
    size::Int
    on_tree_manipulation::Set{Constraint}
    isfeasible::Bool
end

function Base.copy(state::State) 
    State(deepcopy(state.tree), state.size, copy(state.on_tree_manipulation), state.isfeasible)
end
