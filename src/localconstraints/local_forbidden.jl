
"""
Forbids the a subtree that matches the MatchNode tree to be generated at the location 
provided by the path. 
Use a `Forbidden` constraint for enforcing this throughout the entire search space.
"""
mutable struct LocalForbidden <: LocalConstraint
	path::Vector{Int}
    tree::AbstractMatchNode
end

"""
Propagates the LocalForbidden constraint.
It removes rules from the domain that would make
the RuleNode at the given path match the pattern defined by the MatchNode.
"""
function propagate(c::LocalForbidden, ::Grammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}
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

    remove_from_domain::Int = 0
    if match isa Int
        # The domain matched with a rulenode in the match pattern tree
        remove_from_domain = match
    elseif match isa Tuple{Symbol, Vector{Int}}
        # The hole is matched with an otherwise unassigned variable (wildcard).
        return [], []
    end

    # Remove the rule that would complete the forbidden tree from the domain
    loc = findfirst(isequal(remove_from_domain), domain)
    if loc !== nothing
        deleteat!(domain, loc)
    end
    # If the domain is pruned, we do not need this constraint anymore after expansion,
    # since no equality is possible with the new domain.
    return domain, []
end