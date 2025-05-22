"""
    Unique <: AbstractGrammarConstraint

This [`AbstractGrammarConstraint`] enforces that a given `rule` appears in the program tree at most once.
"""
struct Unique <: AbstractGrammarConstraint
    rule::Int
end


function on_new_node(solver::Solver, c::Unique, path::Vector{Int})
    if length(path) == 0
        #only post a local constraint at the root
        post!(solver, LocalUnique(path, c.rule))
    end
end


"""
    function _count_occurrences(rule::Int, node::AbstractRuleNode)::Int

Recursively counts the number of occurrences of the `rule` in the `node`.
"""
function _count_occurrences(node::AbstractRuleNode, rule::Int)::Int
    @assert isfilled(node)
    count = (get_rule(node) == rule) ? 1 : 0
    for child ∈ get_children(node)
        count += _count_occurrences(child, rule)
    end
    return count
end


"""
    function check_tree(c::Unique, tree::AbstractRuleNode)::Bool

Checks if the given [`AbstractRuleNode`](@ref) tree abides the [`Unique`](@ref) constraint.
"""
function check_tree(c::Unique, tree::AbstractRuleNode)::Bool
    return _count_occurrences(tree, c.rule) <= 1
end

"""
	update_rule_indices!(c::Unique, n_rules::Integer)

Updates a `Unique` constraint to reflect grammar changes. No operation is performed 
as `Unique` constraints do not require updates for grammar rule changes.

# Arguments
- `c`: The `Unique` constraint to be updated.
- `n_rules`: The new number of rules in the grammar.
"""
function update_rule_indices!(c::Unique, n_rules::Integer)
    # no update required
end

"""
    HerbCore.update_rule_indices!(c::Unique,
    n_rules::Integer,
    mapping::AbstractDict{<:Integer,<:Integer},
    constraints::Vector{AbstractConstraint})

Updates the `Unique` constraint to reflect grammar changes by replacing it with a new 
`Unique` constraint using the mapped rule index.

# Arguments
- `c`: The `Unique` constraint to be updated
- `n_rules`: The new number of rules in the grammar  
- `mapping`: Dictionary mapping old rule indices to new rule indices
- `constraints`: Vector of grammar constraints containing the constraint to update
"""
function update_rule_indices!(c::Unique,
    n_rules::Integer,
    mapping::AbstractDict{<:Integer,<:Integer},
    constraints::Vector{AbstractConstraint})
    index = findfirst(x -> x == c, c_vector) # assumes no duplicate constraints => TODO: can we assume this?
    new_rule = _get_new_index(c.rule, mapping)
    c_vector[index] = Unique(new_rule)
end