"""
Forbids the subtree to be generated.
A subtree is defined as a tree of `AbstractMatchNode`s. 
Such a node can either be a `MatchNode`, which contains a rule index corresponding to the 
rule index in the grammar of the rulenode we are trying to match.
It can also contain a `MatchVar`, which contains a single identifier symbol.
"""
struct ForbiddenTree <: PropagatorConstraint
	tree::AbstractMatchNode
end


"""
Propagates the ForbiddenTree constraint.
It removes the elements from the domain that would complete the forbidden tree.
"""
function propagate(c::ForbiddenTree, g::Grammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}
    notequals_constraint = NotEquals(context.nodeLocation, c.tree)
    new_domain, new_constraints = propagate(notequals_constraint, g, context, domain)
    return new_domain, new_constraints
end
