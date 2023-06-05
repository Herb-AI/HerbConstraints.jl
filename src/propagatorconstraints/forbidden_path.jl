"""
Forbids the derivation specified as a path in an expression tree.
The rules need to be in the exact order
"""
struct ForbiddenPath <: PropagatorConstraint
	sequence::Vector{Int}
end


"""
Propagates the ForbiddenPath constraint.
It removes the elements from the domain that would complete the forbidden sequence.
"""
function propagate(
    c::ForbiddenPath, 
    ::Grammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{Vector{Int}, Set{LocalConstraint}}
	# Skip the propagator if the hole that was filled isn't a parent of the current hole
	if !isnothing(filled_hole) && filled_hole.path != context.nodeLocation[begin:end-1]
		return domain, Set()
	end

	ancestors = get_rulesequence(context.originalExpr, context.nodeLocation[begin:end-1])
	
	if subsequenceof(c.sequence[begin:end-1], ancestors)
		last_in_seq = c.sequence[end]
		return filter(x -> !(x == last_in_seq), domain), Set()
	end

	return domain, Set()
end
