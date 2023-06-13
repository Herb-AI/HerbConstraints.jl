"""
Rules have to be used in the specified order.
That is, rule at index K can only be used if rules at indices [1...K-1] are used in the left subtree of the current expression
"""
struct OrderedPath <: PropagatorConstraint
	order::Vector{Int}
end


"""
Propagates the OrderedPath constraint.
It removes every element from the domain that does not have a necessary 
predecessor in the left subtree.
"""
function propagate(
    c::OrderedPath, 
    ::Grammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    ::Union{HoleReference, Nothing}
)::Tuple{Vector{Int}, Set{LocalConstraint}}
	# Skip the propagator if the hole that was filled isn't a parent of the current hole
	if !isnothing(filled_hole) && filled_hole.path != context.nodeLocation[begin:end-1]
		return domain, Set()
	end

	rules_on_left = rulesonleft(context.originalExpr, context.nodeLocation)
	
	last_rule_index = 0
	for r in c.order
		r in rules_on_left ? last_rule_index = r : break
	end

	rules_to_remove = Set(c.order[last_rule_index+2:end]) # +2 because the one after the last index can be used

	return filter((x) -> !(x in rules_to_remove), domain), Set()
end