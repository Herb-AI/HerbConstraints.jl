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
