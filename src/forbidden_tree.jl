using Metatheory
using TermInterface

"""
Forbids the subtree to be generated.
"""
struct ForbiddenTree <: PropagatorConstraint
    rule::AbstractRule
    vars::Vector{Symbol}
end

"""
Converts the rulenode to a pattern that is removed from the search space.
Holes are not allowed in the rulenode/pattern.
To use variables, provide the indices of variable rulenodes.
"""
function ForbiddenTree(rn::RuleNode, vars::Vector{Int}=Int[])
    pvars = Symbol[]
    lhs_pattern = rn2pattern(rn, vars, pvars)
    r = DynamicRule(lhs_pattern, (_, _, pvars...) -> pvars, nothing)
    return ForbiddenTree(r, pvars)
end

"""
Converts a rulenode to a pattern that can be used for matching.
No holes allowed!
  - `vars` is a vector of the indices of rules that are variables.
    Every rulenode with one of these indices will be converted to a variable.
  - `pvars` is a vector of the variable symbols in depth-first left-to-right order.
    This vector is modified and can be used for retrieving variable assignments after the match.
"""
function rn2pattern(rn::RuleNode, vars::Vector{Int}, pvars::Vector{Symbol}=Symbol[])::AbstractPat
    if rn.ind ∈ vars
        name = Symbol("x$(rn.ind)")
        name ∈ pvars || push!(pvars, name)
        return PatVar(name)
    else
        return PatTerm(:call, rn.ind, [rn2pattern(c, vars, pvars) for c ∈ rn.children])
    end
end

TermInterface.istree(e::RuleNode) = e.children ≠ []
TermInterface.exprhead(::RuleNode) = :call
TermInterface.operation(e::RuleNode) = e.ind
TermInterface.arguments(e::RuleNode) = e.children
TermInterface.metadata(e::RuleNode) = e._val

"""
Propagates the ForbiddenTree constraint.
It removes the elements from the domain that would complete the forbidden tree.
"""
function propagate(c::ForbiddenTree, ::Grammar, context::GrammarContext, domain::Vector{Int})
    # Hole to be filled
    htbf = get_node_at_location(context.originalExpr, context.nodeLocation)
    @assert htbf isa Hole 
    @assert htbf.expanding

    # We apply the rule at every node between the root and the hole we are expanding.
    # This should be cheaper than doing a full exploration of the tree.
    for i ∈ 0:length(context.nodeLocation)
        n = get_node_at_location(context.originalExpr, context.nodeLocation[1:i])

        # Create a backup of the hole domain
        domain = deepcopy(htbf.domain)

        # Attempt to match the pattern with the RuleNode
        match = c.rule(n)

        if match ≡ nothing
            # The domain might have been changed during the match attempt, so we reset it.
            htbf.domain = domain
            continue
        elseif htbf.domain == domain
            # If the domain was unchanged, but the match successful, 
            # the hole must be assigned to one of the variables.
            # This is essentially a 'wildcard' variable and means the domain is emptied
            @assert htbf ∈ match
            for i ∈ 1:length(htbf.domain)
                htbf.domain[i] = false 
            end
            return []
        end
        # If the domain was changed and the match was successful, we continue with the changed domain.
    end

    # Return index vector of the domain
    return findall(htbf.domain)
end

function capture(pattern, tree)
    
end
