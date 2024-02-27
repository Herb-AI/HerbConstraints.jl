"""
    Condition <: PropagatorConstraint

This [`PropagatorConstraint`](@ref) forbids any subtree that matches the pattern defined by `tree` 
and where the [`RuleNode`](@ref) that is matched to the variable in the pattern violates the predicate given by
the `condition` function.

The `condition` function takes a `RuleNode` tree and should return a `Bool`.

!!! warning
    The [`Condition`](@ref) constraint makes use of [`LocalConstraint`](@ref)s to make sure that constraints 
    are also enforced in the future when the context of a [`Hole`](@ref) changes. 
    Therefore, [`Condition`](@ref) can only be used in implementations that keep track of the 
    [`LocalConstraint`](@ref)s and propagate them at the right moments.
"""
struct Condition <: PropagatorConstraint
    tree::AbstractMatchNode
    condition::Function
end
    

"""
    propagate(c::Condition, g::AbstractGrammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}

Propagates the [`Condition`](@ref) constraint.
Rules that violate the [`Condition`](@ref) constraint are removed from the domain.

!!! warning
    The [`Condition`](@ref) constraint makes use of [`LocalConstraint`](@ref)s to make sure that constraints 
    are also enforced in the future when the context of a [`Hole`](@ref) changes. 
    Therefore, [`Condition`](@ref) can only be used in implementations that keep track of the 
    [`LocalConstraint`](@ref)s and propagate them at the right moments.
"""

function propagate(
    c::Condition, 
    g::AbstractGrammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{PropagatedDomain, Set{LocalConstraint}}
	# Skip the propagator if the hole that was filled isn't a parent of the current hole
	if !isnothing(filled_hole) && filled_hole.path != context.nodeLocation[begin:end-1]
		return domain, Set()
	end

    _condition_constraint = LocalCondition(context.nodeLocation, c.tree, c.condition)
    if in(_condition_constraint, context.constraints) return domain, Set() end

    new_domain, new_constraints = propagate(_condition_constraint, g, context, domain, filled_hole)
    return new_domain, new_constraints
end


"""
Checks if the given tree abides the constraint.
"""
function check_tree(c::Condition, g::AbstractGrammar, tree::RuleNode)::Bool
    vars = Dict{Symbol, AbstractRuleNode}()
    
    # Return false if the node fits the pattern, but not the condition
    if _pattern_match(tree, c.tree, vars) ≡ nothing && !c.condition(vars)
        return false
    end

    return all(check_tree(c, g, child) for child ∈ tree.children)
end

function check_tree(::Condition, ::AbstractGrammar, ::Hole)::Bool
    return false
end
