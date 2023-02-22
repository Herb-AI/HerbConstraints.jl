"""
Forbids the derivation specified as a path in an expression tree.
The rules need to be in the exact order
"""
struct Forbidden <: PropagatorConstraint
	sequence::Vector{Int}
end


"""
Propagates the Forbidden constraint.
It removes the elements from the domain that would complete the forbidden sequence.
"""
function propagate(c::Forbidden, context::GrammarContext, domain::Vector{Int})
	ancestors = get_rulesequence(context.originalExpr, context.nodeLocation[begin:end-1])
	
    if Grammars.subsequenceof(c.sequence[begin:end-1], ancestors)
		last_in_seq = c.sequence[end]
		return filter(x -> !(x == last_in_seq), domain)
	end

	return domain
end


function propagate_index(c::Forbidden, context::GrammarContext, domain::Vector{Int})
	ancestors = get_rulesequence(context.originalExpr, context.nodeLocation[begin:end-1])
	
    if Grammars.subsequenceof(c.sequence[begin:end-1], ancestors)
		last_in_seq = c.sequence[end]
		return reduce((acc, x) -> (!(x[2] == last_in_seq) ? push!(acc, x[1]) : acc), enumerate(domain); init=Vector{Int}())
	end

	return 1:length(domain)
end