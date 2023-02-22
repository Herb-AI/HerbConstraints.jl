"""
Rules have to be used in the specified order.
That is, rule at index K can only be used if rules at indices [1...K-1] are used in the left subtree of the current expression
"""
struct Ordered <: PropagatorConstraint
	order::Vector{Int}
end


"""
Propagates the Ordered constraint.
It removes every element from the domain that does not have a necessary 
predecessor in the left subtree.
"""
function propagate(c::Ordered, context::GrammarContext, domain::Vector{Int})
	rules_on_left = rulesonleft(context.originalExpr, context.nodeLocation)
	
	last_rule_index = 0
	for r in c.order
		r in rules_on_left ? last_rule_index = r : break
	end

	rules_to_remove = Set(c.order[last_rule_index+2:end]) # +2 because the one after the last index can be used

	return filter((x) -> !(x in rules_to_remove), domain) 
end

function propagate_index(c::Ordered, context::GrammarContext, domain::Vector{Int})
	rules_on_left = rulesonleft(context.originalExpr, context.nodeLocation)
	
	last_rule_index = 0
	for r in c.order
		r in rules_on_left ? last_rule_index = r : break
	end

	rules_to_remove = Set(c.order[last_rule_index+2:end]) # +2 because the one after the last index can be used

	return reduce((acc, x) -> (!(x[2] in rules_to_remove) ? push!(acc, x[1]) : acc), enumerate(domain); init=Vector{Int}()) 
end

