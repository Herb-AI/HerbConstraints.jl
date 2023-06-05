"""
Enforces a specific order in MatchVar assignments in the grammar
The tree is defined as a tree of `AbstractMatchNode`s. 
Such a node can either be a `MatchNode`, which contains a rule index corresponding to the 
rule index in the grammar of the rulenode we are trying to match.
It can also contain a `MatchVar`, which contains a single identifier symbol.
The order defines in what order the variable assignments should be. 
For example, if the order is `[x, y]`, the constraint will require 
the assignment to `x` to be less than or equal to the assignment to `y`.
"""
struct Ordered <: PropagatorConstraint
    tree::AbstractMatchNode
    order::Vector{Symbol}
end


"""
Propagates the Ordered constraint.
"""
function propagate(
    c::Ordered, 
    g::Grammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{Vector{Int}, Set{LocalConstraint}}
    ordered_constraint = LocalOrdered(context.nodeLocation, c.tree, c.order)
    if in(ordered_constraint, context.constraints) return domain, Set() end

    new_domain, new_constraints = propagate(ordered_constraint, g, context, domain, filled_hole)
    return new_domain, new_constraints
end

"""
Checks if the given tree abides the constraint.
"""
function check_tree(c::Ordered, g::Grammar, tree::RuleNode)::Bool
    vars = Dict{Symbol, AbstractRuleNode}()
    if _pattern_match(tree, c.tree, vars) ≡ nothing
        # Check variable ordering
        for (var₁, var₂) ∈ zip(c.order[1:end-1], c.order[2:end])
            _rulenode_compare(vars[var₁], vars[var₂]) == 1 && return false
        end
    end
    return all(check_tree(c, g, child) for child ∈ tree.children)
end

check_tree(c::Ordered, g::Grammar, tree::Hole)::Bool = true
