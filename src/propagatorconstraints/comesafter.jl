
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
function propagate(
    c::ComesAfter, 
    ::Grammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{PropagatedDomain, Set{LocalConstraint}}
	# Skip the propagator if the hole that was filled isn't a parent of the current hole
	if !isnothing(filled_hole) && filled_hole.path != context.nodeLocation[begin:end-1]
		return domain, Set()
	end
	
	if c.rule in domain  # if rule is in domain, check the ancestors
		ancestors = get_rulesequence(context.originalExpr, context.nodeLocation[begin:end-1])  # remove the current node from the node sequence
		if containedin(c.predecessors, ancestors)
			return domain, Set()
		else
			return filter(e -> e != c.rule, domain), Set()
		end
	else # if it is not in the domain, just return domain
		return domain, Set()
	end
end


"""
Checks if the given tree abides the constraint.
"""
function check_tree(c::ComesAfter, g::Grammar, tree::AbstractRuleNode)::Bool
	@warn "ComesAfter.check_tree not implemented!"

	return true
end
