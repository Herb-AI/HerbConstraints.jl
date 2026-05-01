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
struct SolverState{T<:AbstractRuleNode}
    tree::T
    active_constraints::Set# {AbstractLocalConstraint}
    isfeasible::Bool
end

get_tree(s::SolverState) = s.tree
get_active_constraints(s::SolverState) = s.active_constraints
isfeasible(s::SolverState) = s.isfeasible

SolverState(tree::AbstractRuleNode) = SolverState(tree, Set(), true)

function Base.copy(state::SolverState)
    tree = deepcopy(state.tree)
    active_constraints = copy(state.active_constraints) # constraints are stateless, so the constraints can be shallow copied
    SolverState(tree, active_constraints, state.isfeasible)
end

