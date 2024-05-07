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
