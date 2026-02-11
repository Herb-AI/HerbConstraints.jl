"""
ContainsAny <: AbstractGrammarConstraint
This [`AbstractGrammarConstraint`] enforces that at least one of the given `rules`
appears in the program tree.
"""
struct ContainsAny <: AbstractGrammarConstraint
    rules::Vector{Int}
end

function on_new_node(solver::Solver, c::ContainsAny, path::Vector{Int})
    if length(path) == 0
        #only post a local constraint at the root
        post!(solver, LocalContainsAny(path, c.rules))
    end
end

"""
    check_tree(c::ContainsAny, tree::AbstractRuleNode)::Bool

Checks if the given [`AbstractRuleNode`](@ref) tree abides the [`ContainsAny`](@ref) constraint.
"""
function check_tree(c::ContainsAny, tree::AbstractRuleNode)::Bool
    if get_rule(tree) in c.rules
        return true
    end
    return any(check_tree(c, child) for child ∈ get_children(tree))
end

"""
    update_rule_indices!(c::ContainsAny, n_rules::Integer)

Updates a `ContainsAny` constraint to reflect grammar changes. Errors if any rule index exceeds new `n_rules`.

# Arguments
- `c`: The `ContainsAny` constraint to be updated
- `n_rules`: The new number of rules in the grammar
"""
function HerbCore.update_rule_indices!(c::ContainsAny, n_rules::Integer)
    if any(rule -> rule > n_rules, c.rules)
        error("Rule index in $(c.rules) exceeds the number of grammar rules ($n_rules).")
    end
    # no update required
end

"""
    update_rule_indices!(c::ContainsAny, grammar::AbstractGrammar)

Updates the `ContainsAny` constraint as required when grammar size changes. Errors if any rule index exceeds number of grammar rules.

# Arguments
- `c`: The `ContainsAny` constraint to be updated
- `grammar`: The grammar that changed
"""
function HerbCore.update_rule_indices!(c::ContainsAny, grammar::AbstractGrammar)
    n_rules = length(grammar.rules)
    if any(rule -> rule > n_rules, c.rules)
        error("Rule index in $(c.rules) exceeds the number of grammar rules ($n_rules).")
    end
    # no update required
end

"""
    update_rule_indices!(c::ContainsAny, n_rules::Integer, mapping::AbstractDict{<:Integer,<:Integer}, constraints::Vector{<:AbstractConstraint})

Updates the `ContainsAny` constraint to reflect grammar changes by replacing it with a new
`ContainsAny` constraint using the mapped rule indices.

# Arguments
- `c`: The `ContainsAny` constraint to be updated
- `n_rules`: The new number of grammar rules
- `mapping`: Dictionary mapping old rule indices to new rule indices
- `constraints`: Vector of grammar constraints containing the constraint to update
"""
function HerbCore.update_rule_indices!(
    c::ContainsAny,
    n_rules::Integer,
    mapping::AbstractDict{<:Integer,<:Integer},
    constraints::Vector{<:AbstractConstraint}
)
    if any(rule -> rule > n_rules, c.rules)
        error("Rule index in $(c.rules) exceeds the number of grammar rules ($n_rules).")
    end
    index = only(findall(x -> x == c, constraints))
    new_rules = [get(mapping, rule, rule) for rule in c.rules]
    constraints[index] = ContainsAny(new_rules)
end

"""
    update_rule_indices!(c::ContainsAny, grammar::AbstractGrammar, mapping::AbstractDict{<:Integer,<:Integer})

Updates the `ContainsAny` constraint to reflect grammar changes by replacing it with a new
`ContainsAny` constraint using the mapped rule indices.

# Arguments
- `c`: The `ContainsAny` constraint to be updated
- `grammar`: The grammar that changed
- `mapping`: Dictionary mapping old rule indices to new rule indices
"""
function HerbCore.update_rule_indices!(c::ContainsAny,
    grammar::AbstractGrammar,
    mapping::AbstractDict{<:Integer,<:Integer})
    HerbCore.update_rule_indices!(c, length(grammar.rules), mapping, grammar.constraints)
end

HerbCore.is_domain_valid(c::ContainsAny, n_rules::Integer) = all(rule -> rule <= n_rules, c.rules)
HerbCore.is_domain_valid(c::ContainsAny, grammar::AbstractGrammar) = HerbCore.is_domain_valid(c, length(grammar.rules))

HerbCore.issame(c1::ContainsAny, c2::ContainsAny) = c1.rules == c2.rules
