"""
Contains <: AbstractGrammarConstraint
This [`AbstractGrammarConstraint`] enforces that a given `rule` appears in the program tree at least once.
"""
struct Contains <: AbstractGrammarConstraint
    rule::Int
end

function on_new_node(solver::Solver, c::Contains, path::Vector{Int})
    if length(path) == 0
        #only post a local constraint at the root
        post!(solver, LocalContains(path, c.rule))
    end
end

"""
    check_tree(c::Contains, tree::AbstractRuleNode)::Bool

Checks if the given [`AbstractRuleNode`](@ref) tree abides the [`Contains`](@ref) constraint.
"""
function check_tree(c::Contains, tree::AbstractRuleNode)::Bool
    if get_rule(tree) == c.rule
        return true
    end
    return any(check_tree(c, child) for child ∈ get_children(tree))
end


"""
	update_rule_indices!(c::Contains, n_rules::Integer)

Updates a `Contains` constraint to reflect grammar changes. No operation is performed 
as `Contains` constraints do not require updates for grammar rule changes.

# Arguments
- `c`: The `Contains` constraint to be updated
- `n_rules`: The new number of rules in the grammar
"""
function HerbCore.update_rule_indices!(c::Contains, n_rules::Integer)
    # no update required
end

"""
	update_rule_indices!(c::Contains, grammar::AbstractGrammar)

Updates a `Contains` constraint to reflect grammar changes. No operation is performed 
as `Contains` constraints do not require updates for grammar rule changes.

# Arguments
- `c`: The `Contains` constraint to be updated
- `grammar`: The grammar that changed
"""
function HerbCore.update_rule_indices!(c::Contains, grammar::AbstractGrammar)
    # no update required
end

"""
    update_rule_indices!(c::Contains, n_rules::Integer, mapping::AbstractDict{<:Integer,<:Integer}, constraints::Vector{<:AbstractConstraint})

Updates the `Contains` constraint to reflect grammar changes by replacing it with a new 
`Contains` constraint using the mapped rule index.

# Arguments
- `c`: The `Contains` constraint to be updated
- `n_rules`: The new number of rules in the grammar  
- `mapping`: Dictionary mapping old rule indices to new rule indices
- `constraints`: Vector of grammar constraints containing the constraint to update
"""
function HerbCore.update_rule_indices!(
    c::Contains,
    n_rules::Integer,
    mapping::AbstractDict{<:Integer,<:Integer},
    constraints::Vector{<:AbstractConstraint}
)
    index = only(findall(x -> x == c, constraints))
    new_rule = _get_new_index(c.rule, mapping)
    constraints[index] = Contains(new_rule)
end

"""
    update_rule_indices!(c::Contains, grammar::AbstractGrammar, mapping::AbstractDict{<:Integer,<:Integer})

Updates the `Contains` constraint to reflect grammar changes by replacing it with a new 
`Contains` constraint using the mapped rule index.

# Arguments
- `c`: The `Contains` constraint to be updated
- `grammar`: The grammar that changed  
- `mapping`: Dictionary mapping old rule indices to new rule indices
"""
function HerbCore.update_rule_indices!(c::Contains,
    grammar::AbstractGrammar,
    mapping::AbstractDict{<:Integer,<:Integer})
    HerbCore.update_rule_indices!(c, length(grammar.rules), mapping, grammar.constraints)
end