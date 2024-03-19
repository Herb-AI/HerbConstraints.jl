"""
    mutable struct State 

A state to be solved by the [`GenericSolver`](@ref).
A state contains of:

- `tree`: A partial AST
- `activeconstraints`: The local constraints that apply to this tree. 
   These constraints are enforced each time the tree is modified.
- `isfeasible`: Flag to indicate if this state is still feasible.
   When a propagator spots an inconsistency, this field will be set to false.
   Tree manipulations and further propagations are not allowed on infeasible states
"""
mutable struct State
    tree::AbstractRuleNode
    activeconstraints::Set{Constraint}
    isfeasible::Bool
end

State(tree::AbstractRuleNode) = State(tree, Set{Constraint}(), true)

function Base.copy(state::State) 
    tree = deepcopy(state.tree)
    activeconstraints = copy(state.activeconstraints) # constraints are stateless, so the constraints can be shallow copied
    State(tree, activeconstraints, state.isfeasible)
end

