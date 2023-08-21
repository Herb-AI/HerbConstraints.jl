"""
    Ordered <: PropagatorConstraint

A [`PropagatorConstraint`](@ref) that enforces a specific order in [`MatchVar`](@ref) 
assignments in the pattern defined by `tree`.
A pattern is a tree of [`AbstractMatchNode`](@ref)s. 
Such a node can either be a [`MatchNode`](@ref), which contains a rule index corresponding to the 
rule index in the [`Grammar`](@ref) and the appropriate number of children, similar to [`RuleNode`](@ref)s.
It can also contain a [`MatchVar`](@ref), which contains a single identifier symbol.
A [`MatchVar`](@ref) can match any subtree, but if there are multiple instances of the same
variable in the pattern, the matched subtrees must be identical.

The `order` defines an order between the variable assignments. 
For example, if the order is `[x, y]`, the constraint will require 
the assignment to `x` to be less than or equal to the assignment to `y`.
The order is recursively defined by [`RuleNode`](@ref) indices. 
For more information, see [`Base.isless(rn₁::AbstractRuleNode, rn₂::AbstractRuleNode)`](@ref).

For example, consider the tree `1(a, 2(b, 3(c, 4))))`:

- `Ordered(MatchNode(3, [MatchVar(:v), MatchVar(:w)]), [:v, :w])` removes every rule 
  with an index of 5 or greater from the domain of `c`, since that would make the index of the 
  assignment to `v` greater than the index of the assignment to `w`, violating the order.
- `Ordered(MatchNode(3, [MatchVar(:v), MatchVar(:w)]), [:w, :v])` removes every rule 
  with an index of 4 or less from the domain of `c`, since that would make the index of the 
  assignment to `v` less than the index of the assignment to `w`, violating the order.

!!! warning
    The [`Ordered`](@ref) constraint makes use of [`LocalConstraint`](@ref)s to make sure that constraints 
    are also enforced in the future when the context of a [`Hole`](@ref) changes. 
    Therefore, [`Ordered`](@ref) can only be used in implementations that keep track of the 
    [`LocalConstraint`](@ref)s and propagate them at the right moments.
"""
struct Ordered <: PropagatorConstraint
    tree::AbstractMatchNode
    order::Vector{Symbol}
end


"""
    propagate(c::Ordered, g::Grammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}

Propagates the [`Ordered`](@ref) constraint.
Any rule that violates the order as defined by the contraint is removed from the `domain`.

!!! warning
    The [`Ordered`](@ref) constraint makes use of [`LocalConstraint`](@ref)s to make sure that constraints 
    are also enforced in the future when the context of a [`Hole`](@ref) changes. 
    Therefore, [`Ordered`](@ref) can only be used in implementations that keep track of the 
    [`LocalConstraint`](@ref)s and propagate them at the right moments.
"""
function propagate(
    c::Ordered, 
    g::Grammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{PropagatedDomain, Set{LocalConstraint}}
	# Skip the propagator if the hole that was filled isn't a parent of the current hole
	if !isnothing(filled_hole) && filled_hole.path != context.nodeLocation[begin:end-1]
		return domain, Set()
	end

    ordered_constraint = LocalOrdered(context.nodeLocation, c.tree, c.order)
    if in(ordered_constraint, context.constraints) return domain, Set() end

    new_domain, new_constraints = propagate(ordered_constraint, g, context, domain, filled_hole)
    return new_domain, new_constraints
end

"""
    check_tree(c::Ordered, g::Grammar, tree::RuleNode)::Bool

Checks if the given [`AbstractRuleNode`](@ref) tree abides the [`Ordered`](@ref) constraint.
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
