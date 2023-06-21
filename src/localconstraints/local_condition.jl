mutable struct LocalCondition <: LocalConstraint
    path::Vector{Int}
    tree::AbstractMatchNode
    condition::Function
end

function propagate(
    c::LocalCondition, 
    ::Grammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{PropagatedDomain, Set{LocalConstraint}}
    # Skip the propagator if a node is being propagated that it isn't targeting
    if length(c.path) > length(context.nodeLocation) || c.path ≠ context.nodeLocation[1:length(c.path)]
        return unchanged_domain, Set([c])
    end

    # Skip the propagator if the filled hole wasn't part of the path
	if !isnothing(filled_hole) && (length(c.path) > length(filled_hole.path) || c.path ≠ filled_hole.path[1:length(c.path)])
		return unchanged_domain, Set([c])
	end

    n = get_node_at_location(context.originalExpr, c.path)

    hole_location = context.nodeLocation[length(c.path)+1:end]

    vars = Dict{Symbol, AbstractRuleNode}()

    match = _pattern_match_with_hole(n, c.tree, hole_location, vars)
    if match ≡ hardfail
        # Match attempt failed due to mismatched rulenode indices. 
        # This means that we can remove the current constraint.
        return unchanged_domain, Set()
    elseif match ≡ softfail
        # Match attempt failed because we had to compare with a hole. 
        # If the hole would've been filled it might have succeeded, so we cannot yet remove the constraint.
        return unchanged_domain, Set([c])
    end

    function is_in_domain(rule)
        vars_copy = copy(vars)
        vars_copy[match[1]] = RuleNode(rule)
        return c.condition(vars_copy)
    end

    return filter(is_in_domain, domain), Set()
end