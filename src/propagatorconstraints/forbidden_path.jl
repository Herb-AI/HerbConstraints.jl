"""
	ForbiddenPath <: PropagatorConstraint

A [`PropagatorConstraint`] that forbids a certain derivation sequence.
`sequence` defines the forbidden sequence. 
Each rule that would complete the sequence when expanding a [`Hole`](@ref) in an 
[`AbstractRuleNode`](@ref) tree is removed from the domain.
The derivation sequence is the path from the root to the hole.

For example, consider the tree `1(a, 2(b, 3(c, d))))`:

- `ForbiddenPath([1, 2, 4])` enforces that rule `4` cannot be applied at `b`, 
  since it completes the sequence. However, it can be applied at `a`, `c` and `d`.
- `ForbiddenPath([3, 1])` enforces that rule `1` cannot be applied at `c` or `d`.
"""
struct ForbiddenPath <: PropagatorConstraint
	sequence::Vector{Int}
end


"""
Propagates the [`ForbiddenPath`](@ref) constraint.
It removes the elements from the domain that would complete the forbidden sequence.
"""
function propagate(
    c::ForbiddenPath, 
    ::AbstractGrammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{PropagatedDomain, Set{LocalConstraint}}
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


"""
Checks if the given tree abides the constraint.
"""
function check_tree(c::ForbiddenPath, g::AbstractGrammar, tree::AbstractRuleNode)::Bool
	@warn "ForbiddenPath.check_tree not implemented!"

	return true
end
