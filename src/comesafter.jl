
"""
Derivation rule can only appear in a derivation tree if the predecessors are in the path to the current node (in order)
"""
struct ComesAfter <: PropagatorConstraint
	rule::Int 
	predecessors::Vector{Int}
end

ComesAfter(rule::Int, predecessor::Int) = ComesAfter(rule, [predecessor])

"""
Propagates the ComesAfter constraint.
It removes the rule from the domain if the predecessors sequence is in the ancestors.
"""
function propagate(c::ComesAfter, ::Grammar, context::GrammarContext, domain::Vector{Int})
	ancestors = get_rulesequence(context.originalExpr, context.nodeLocation[begin:end-1])  # remove the current node from the node sequence
	if c.rule in domain  # if rule is in domain, check the ancestors
		if containedin(c.predecessors, ancestors)
			return domain
		else
			return filter(e -> e != c.rule, domain)
		end
	else # if it is not in the domain, just return domain
		return domain
	end
end
