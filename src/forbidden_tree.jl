"""
Forbids the subtree to be generated.
A subtree is defined as a tree of `AbstractMatchNode`s. 
Such a node can either be a `MatchNode`, which contains a rule index corresponding to the 
rule index in the grammar of the rulenode we are trying to match.
It can also contain a `MatchVar`, which contains a single identifier symbol.
"""
struct ForbiddenTree <: PropagatorConstraint
	tree::AbstractMatchNode
end


"""
Propagates the ForbiddenTree constraint.
It removes the elements from the domain that would complete the forbidden tree.
"""
function propagate(c::ForbiddenTree, ::Grammar, context::GrammarContext, domain::Vector{Int})
    for i ∈ 0:length(context.nodeLocation)
        n = get_node_at_location(context.originalExpr, context.nodeLocation[1:i])
        match = _match_tree_containing_hole(n, c.tree, context.nodeLocation[i+1:end], Dict{Symbol, RuleNode}())
        
        # Immediately go to next level if match is unsuccessful
        match ≡ nothing && continue

        domain_match, vars = match
        remove_from_domain::Int=0
        if domain_match isa Symbol
            if domain_match ∉ keys(vars)
                # Variable is not assigned, so it acts as a wildcard
                return []
            elseif vars[domain_match].children == []
                # A terminal rulenode is assigned to the variable, so we retrieve the assigned value
                remove_from_domain = vars[domain_match].ind
            else
                # A non-terminal rulenode is assigned to the variable.
                # This is too specific to reduce the domain.
                continue
            end
        elseif domain_match isa Int
            # The domain match is an actual (terminal) rule.
            # 0 is the special case for when any rule matches the hole.
            domain_match == 0 && return []
            remove_from_domain = domain_match
        end

        # Remove the rule that would complete the forbidden tree from the domain
        loc = findfirst(isequal(remove_from_domain), domain)
        if loc !== nothing
            deleteat!(domain, loc)
        end

        # No need to match in other layers if the domain is empty 
        domain == [] && return []
    end
    return domain
end


# Matching RuleNode with MatchNode
"""
Tries to match RuleNode `rn` with MatchNode `cmn` and fill in 
the domain of the hole at `hole_location`. 
Returns if match is successful:
  - A dictionary with variable assignments
  - Either 
    - The id for the node which fills the hole
    - 0 if any node could fill the hole
    - A symbol for the variable that fills the hole
A variable is represented by the index of its rulenode.
Returns nothing if the match is unsuccessful.
"""
function _match_tree_containing_hole(
    rn::RuleNode, 
    cmn::MatchNode, 
    hole_location::Vector{Int},
    vars::Dict{Symbol, RuleNode}
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, Nothing}
    hole_location == [] && throw(ArgumentError("The hole location doesn't point to a hole!"))

    if rn.ind ≠ cmn.rule_ind || length(rn.children) ≠ length(cmn.children)
        return nothing
    else
        child_tuples = collect(zip(rn.children, cmn.children))

        # Match all children that aren't part of the path to the hole
        for (rnᵢ, cmnᵢ) ∈ Iterators.flatten((child_tuples[1:hole_location[1]-1], child_tuples[hole_location[1]+1:end]))
            varsᵢ = _match_tree(rnᵢ, cmnᵢ)
            # Immediately return if we didn't get a match
            varsᵢ ≡ nothing && return nothing

            # Update variables and check if another instance has a different assignment
            if !_update_variables!(vars, varsᵢ)
                return nothing
            end
        end

        # Match the child that is on the path to the hole. 
        # Doing this in after all other children makes sure all variables are assigned when the hole is matched.
        rnᵢ = rn.children[hole_location[1]]
        cmnᵢ = cmn.children[hole_location[1]]
        match = _match_tree_containing_hole(rnᵢ, cmnᵢ, hole_location[begin+1:end], vars)

        # Immediately return if we didn't get a match
        match ≡ nothing && return nothing

        domain, varsᵢ = match
        # Update variables and check if another instance has a different assignment
        if !_update_variables!(vars, varsᵢ)
            return nothing
        end
        return domain, vars
    end
end

# Matching RuleNode with MatchVar
function _match_tree_containing_hole(rn::RuleNode, cmn::MatchVar, hole_location::Vector{Int}, vars::Dict{Symbol, RuleNode}
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, Nothing}
    if cmn.var_name ∈ keys(vars)
        match = _get_domain_from_rulenodes(rn, vars[cmn.var_name], hole_location)
        match ≡ nothing && return nothing
        return (match, Dict())
    end
    # 0 is the special case for matching any rulenode.
    # This is the case if the hole matches an unassigned variable (wildcard).
    return (0, Dict(cmn.var_name => rn))
end

# Matching Hole with MatchNode
_match_tree_containing_hole(::Hole, cmn::MatchNode, hole_location::Vector{Int}, ::Dict{Symbol, RuleNode}
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, Nothing} = 
    hole_location == [] && cmn.children == [] ? (cmn.rule_ind, Dict()) : nothing

# Matching Hole with MatchVar
_match_tree_containing_hole(::Hole, cmn::MatchVar, hole_location::Vector{Int}, ::Dict{Symbol, RuleNode}
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, Nothing} =
    hole_location == [] ? (cmn.var_name, Dict()) : nothing


# Matching RuleNode with MatchNode
"""
Tries to match RuleNode `rn` with MatchNode `cmn`.
Returns a dictionary of values assigned to variables if the match is successful.
"""
function _match_tree(rn::RuleNode, cmn::MatchNode)::Union{Dict{Symbol, RuleNode}, Nothing}  
    if rn.ind ≠ cmn.rule_ind || length(rn.children) ≠ length(cmn.children)
        return nothing
    else
        # Root nodes match, now we check the child nodes
        vars::Dict{Symbol, RuleNode} = Dict()
        for varsᵢ ∈ map(ab -> _match_tree(ab[1], ab[2]), zip(rn.children, cmn.children)) 
            # Immediately return if we didn't get a match
            varsᵢ ≡ nothing && return nothing

            # Update variables and check if another instance has a different assignment
            if !_update_variables!(vars, varsᵢ)
                return nothing
            end
        end
        return vars
    end
end

# Matching RuleNode with MatchVar
_match_tree(rn::RuleNode, cmn::MatchVar)::Union{Dict{Symbol, RuleNode}, Nothing} = Dict(cmn.var_name => rn)

# Matching Hole
_match_tree(::Hole, ::AbstractMatchNode)::Union{Dict{Symbol, RuleNode}, Nothing} = nothing


"""
Matches two rulenodes. 
Returns how to fill in the hole in rn₁ to make it match rn₂ if:
  - rn₁ has a single hole at the provided location
  - rn₂ doesn't have any holes
  - rn₁ matches rn₂ apart from the single hole location.
If one or more of these conditions aren't met, nothing is returned. 
"""
function _get_domain_from_rulenodes(rn₁::RuleNode, rn₂::RuleNode, hole_location::Vector{Int})
    if rn₁.ind ≠ rn₂.ind || hole_location == [] || length(rn₁.children) ≠ length(rn₂.children)
        return nothing
    else
        domain = nothing
        for (i, c₁, c₂) ∈ zip(Iterators.countfrom(), rn₁.children, rn₂.children)
            if i == hole_location[1]
                domain = _get_domain_from_rulenodes(c₁, c₂, hole_location[2:end])
                # Immediately return if we didn't get a match
                domain ≡ nothing && return nothing
            elseif c₁ ≠ c₂
                return nothing
            end
        end
        return domain
    end
end

function _get_domain_from_rulenodes(::Hole, rn₂::RuleNode, hole_location::Vector{Int})
    if hole_location == [] && rn₂.children == []
        return rn₂.ind
    end
    return nothing
end

_get_domain_from_rulenodes(::AbstractRuleNode, ::Hole) = nothing


"""
Updates the existing variables with the new variables.
Returns true if there are no conflicting assignments.
"""
function _update_variables!(existing_vars::Dict{Symbol, RuleNode}, new_vars::Dict{Symbol, RuleNode})::Bool
    for (k, v) ∈ new_vars
        if k ∈ keys(existing_vars) 
            # If the assignments are unequal, the match is unsuccessful
            # Additionally, if the trees are equal but contain a hole, 
            # we cannot reason about equality because we don't know how
            # the hole will be expanded yet.
            if v ≠ existing_vars[k] || contains_hole(v)
                return false
            end
        end
        existing_vars[k] = v
    end
    return true
end
