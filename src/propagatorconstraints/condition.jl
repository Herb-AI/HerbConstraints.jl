struct Condition <: PropagatorConstraint
    tree::AbstractMatchNode
    condition::Function
end
    

function propagate(
    c::Condition, 
    g::Grammar, 
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
function check_tree(c::Condition, g::Grammar, tree::RuleNode)::Bool
    vars = Dict{Symbol, AbstractRuleNode}()
    
    # Return false if the node fits the pattern, but not the condition
    if _pattern_match(tree, c.tree, vars) ≡ nothing && !c.condition(vars)
        return false
    end

    return all(check_tree(c, g, child) for child ∈ tree.children)
end

function check_tree(::Condition, ::Grammar, ::Hole)::Bool
    return false
end
