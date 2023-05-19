mutable struct LocalProgrammatic <: LocalConstraint
    path::Vector{Int}
    tree::AbstractMatchNode
    condition::Function
end

function propagate(c::LocalProgrammatic, ::Grammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}
    if length(c.path) > length(context.nodeLocation) || c.path ≠ context.nodeLocation[1:length(c.path)]
        return domain, [c]
    end

    n = get_node_at_location(context.originalExpr, c.path)

    hole_location = context.nodeLocation[length(c.path)+1:end]

    vars = Dict{Symbol, AbstractRuleNode}()

    match = _pattern_match_with_hole(n, c.tree, hole_location, vars)
    if match ≡ hardfail
        # Match attempt failed due to mismatched rulenode indices. 
        # This means that we can remove the current constraint.
        return domain, []
    elseif match ≡ softfail
        # Match attempt failed because we had to compare with a hole. 
        # If the hole would've been filled it might have succeeded, so we cannot yet remove the constraint.
        return domain, [c]
    end

    function is_in_domain(rule)
        vars_copy = copy(vars)
        vars_copy[match[1]] = RuleNode(rule)
        return c.condition(vars_copy)
    end

    # Cannot remove the propagator (I think?) as assignments to other holes could still make it invalid
    return filter(is_in_domain, domain), [c]
end