"""
Contains <: GrammarConstraint
This [`GrammarConstraint`] enforces that a given `rule` appears in the program tree at least once.
"""
struct Contains <: GrammarConstraint
    rule::Int
end

function on_new_node(solver::Solver, contraint::Contains, path::Vector{Int})
    if length(path) == 0
        #only post a local constraint at the root
        post!(solver, LocalContains(path, contraint.rule))
    end
end

"""
    check_tree(c::Forbidden, g::AbstractGrammar, tree::RuleNode)::Bool

Checks if the given [`AbstractRuleNode`](@ref) tree abides the [`Forbidden`](@ref) constraint.
"""
function check_tree(contraint::Contains, tree::AbstractRuleNode)::Bool
    if get_rule(tree) == contraint.rule
        return true
    end
    return any(check_tree(contraint, child) for child ∈ get_children(tree))
end
