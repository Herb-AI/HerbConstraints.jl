"""
    ContainsSubtree <: AbstractGrammarConstraint

This [`AbstractGrammarConstraint`] enforces that a given `subtree` appears in the program tree at least once.

!!! warning:
    This constraint can only be propagated by the UniformSolver
"""
struct ContainsSubtree <: AbstractGrammarConstraint
    tree::AbstractRuleNode
end

function on_new_node(solver::UniformSolver, c::ContainsSubtree, path::Vector{Int})
    if length(path) == 0
        post!(solver, LocalContainsSubtree(path, c.tree, nothing, nothing))
    end
end

function on_new_node(::GenericSolver, ::ContainsSubtree, ::Vector{Int}) end

"""
    check_tree(c::ContainsSubtree, tree::AbstractRuleNode)::Bool

Checks if the given [`AbstractRuleNode`](@ref) tree abides the [`ContainsSubtree`](@ref) constraint.
"""
function check_tree(c::ContainsSubtree, tree::AbstractRuleNode)::Bool
    if pattern_match(c.tree, tree) isa PatternMatchSuccess
        return true
    end
    return any(check_tree(c, child) for child ∈ get_children(tree))
end

"""
	update_rule_indices!(c::ContainsSubtree, n_rules::Integer)

Updates the `ContainsSubtree` constraint to reflect grammar changes. Calls `HerbCore.update_rule_indices!` its `tree` field.

# Arguments
- `c`: The `ContainsSubtree` constraint to be updated.
- `n_rules`: The new number of rules in the grammar.

# Notes
This function ensures that every node of the `tree` field of the `ContainsSubtree` constraint is updated as required.
"""
function update_rule_indices!(
    c::ContainsSubtree,
    n_rules::Integer,
)
    HerbCore.update_rule_indices!(c.tree, n_rules)
end

"""
	update_rule_indices!(c::ContainsSubtree, n_rules::Integer, mapping::AbstractDict{<:Integer, <:Integer})

Updates the `ContainsSubtree` constraint to reflect grammar changes. Calls `HerbCore.update_rule_indices!` its `tree` field.

# Arguments
- `c`: The `ContainsSubtree` constraint to be updated.
- `n_rules`: The new number of rules in the grammar.
- `mapping`: A dictionary mapping old rule indices to new rule indices

# Notes
This function ensures that every node of the `tree` field of the `ContainsSubtree` constraint is updated as required.
"""
function update_rule_indices!(
    c::ContainsSubtree,
    n_rules::Integer,
    mapping::AbstractDict{<:Integer,<:Integer},
)
    HerbCore.update_rule_indices!(c.tree, n_rules, mapping)
end
