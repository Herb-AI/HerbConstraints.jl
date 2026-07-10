"""
    mutable struct SolverState 

A state to be solved by the [`GenericSolver`](@ref).
A state contains of:

- `tree`: A partial AST
- `active_constraints`: The local constraints that apply to this tree. 
   These constraints are enforced each time the tree is modified.
- `isfeasible`: Flag to indicate if this state is still feasible.
   When a propagator spots an inconsistency, this field will be set to false.
   Tree manipulations and further propagations are not allowed on infeasible states
"""
mutable struct SolverState{R<:AbstractRuleNode, C}
    tree::R
    active_constraints::Set{C}
    isfeasible::Bool
end
SolverState(tree::AbstractRuleNode) = SolverState{AbstractRuleNode,AbstractLocalConstraint}(tree, Set{AbstractLocalConstraint}(), true)
SolverState{R,C}(tree::R) where {R, C} = SolverState{R,C}(tree, Set{C}(), true)

function Base.copy(state::SolverState{R,C}) where {R, C}
    tree = deepcopy(state.tree)
    active_constraints = copy(state.active_constraints) # constraints are stateless, so the constraints can be shallow copied
    SolverState{R, C}(tree, active_constraints, state.isfeasible)
end

