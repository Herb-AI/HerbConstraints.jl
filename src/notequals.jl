mutable struct NotEquals <: LocalConstraint
	path::Vector{Int}
    tree::MatchNode
end

function propagate(c::NotEquals, ::Grammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}
    if length(c.path) > length(context.nodeLocation) || c.path ≠ context.nodeLocation[1:length(c.path)]
        return domain, [c]
    end

    n = get_node_at_location(context.originalExpr, c.path)

    hole_location = context.nodeLocation[length(c.path)+1:end]

    # TODO: Create a single var dict that is modified instead of creating multiples and combining.
    # Instead of a dict, we might also be able to use e.g. a tuple or vector.
    match = _match_tree_containing_hole(n, c.tree, hole_location, Dict{Symbol, RuleNode}())
    
    if match ≡ nothing
        # Match attempt failed due to mismatched rulenode indices. 
        # This means that we can remove the current constraint.
        return domain, []
    elseif match ≡ missing
        # Match attempt failed because we had to compare with a hole. 
        # If the hole would've been filled it might have succeeded, so we cannot yet remove the constraint.
        return domain, [c]
    end

    domain_match, vars = match
    remove_from_domain::Int = 0
    if domain_match isa Symbol
        # The domain matched with a variable in the match pattern tree
        if domain_match ∉ keys(vars)
            # Variable is not assigned, so it acts as a wildcard
            return [], []
        elseif vars[domain_match].children == []
            # A terminal rulenode is assigned to the variable, so we retrieve the assigned value
            remove_from_domain = vars[domain_match].ind
        else
            # A non-terminal rulenode is assigned to the variable.
            # This is too specific to reduce the domain.
            return domain, [c]
        end
    elseif domain_match isa Int
        # The domain matched with a rulenode in the match pattern tree
        # The match function returns a domain of 0 if the hole is matched 
        # with an otherwise unassigned variable (wildcard).
        domain_match == 0 && return [], []
        remove_from_domain = domain_match
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