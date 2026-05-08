module Next
using DispatchDoctor: @stable

@stable begin
struct GrammarConstraint{R<:AbstractRuleNode} <: AbstractGrammarConstraint
    tree::R
end
get_tree(gc::GrammarConstraint) = gc.tree
struct LocalConstraint{C<:AbstractGrammarConstraint} <: AbstractLocalConstraint
    constraint::C
    path::Vector{Int}
end
get_constraint(lc::LocalConstraint) = lc.constraint
get_tree(lc::LocalConstraint) = get_tree(get_constraint(lc))
get_path(lc::LocalConstraint) = lc.path

mutable struct SolverState{R<:AbstractRuleNode, S<:AbstractSet{<:AbstractLocalConstraint}}
    tree::R
    active_constraints::S
    isfeasible::Bool
end

SolverState(tree::AbstractRuleNode) = SolverState(tree, Set{AbstractLocalConstraint}(), true)

function Base.copy(state::SolverState) 
    tree = deepcopy(state.tree)
    active_constraints = copy(state.active_constraints) # constraints are stateless, so the constraints can be shallow copied
    SolverState(tree, active_constraints, state.isfeasible)
end

end # @stable
end # module
