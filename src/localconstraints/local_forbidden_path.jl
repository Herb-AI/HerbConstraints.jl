"""
	ForbiddenPath <: PropagatorConstraint

A [`PropagatorConstraint`] that forbids a certain derivation sequence.
`sequence` defines the forbidden sequence. 
Each rule that would complete the sequence when expanding a [`AbstractHole`](@ref) in an 
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


struct LocalForbiddenPath <: LocalConstraint
	path::Vector{Int}
    sequence::Vector{Int}                   #[1, 2]
    sequence_does_not_contain::Vector{Int}  #[3] # double negation: FORBID if sequence does NOT contain a 3.
end                                         # Having a 3 on the path means the constraint is satisfied.


# Examples:
# [3, 1, 2] is forbidden
# [1, 2, 3] is forbidden
# [1, 3, 2] is NOT forbidden
