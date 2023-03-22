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
function propagate(c::ForbiddenTree, ::Grammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}
    
    # TODO: This returned constraint will only be checked in subsequent iterations. 
    # Should we run it already in case the match node has a single rulenode or variable?
    return NotEquals(context.nodeLocation, c.tree)

    match = _match_tree_containing_hole(n, c.tree, context.nodeLocation[i+1:end], Dict{Symbol, RuleNode}())
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
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, Nothing, Missing}
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
        match ≡ missing && return missing

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
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, Nothing, Missing}
    if cmn.var_name ∈ keys(vars)
        match = _get_domain_from_rulenodes(rn, vars[cmn.var_name], hole_location)
        match ≡ nothing && return nothing
        match ≡ missing && return missing
        return (match, Dict())
    end
    # 0 is the special case for matching any rulenode.
    # This is the case if the hole matches an unassigned variable (wildcard).
    return (0, Dict(cmn.var_name => rn))
end

# Matching Hole with MatchNode
_match_tree_containing_hole(::Hole, cmn::MatchNode, hole_location::Vector{Int}, ::Dict{Symbol, RuleNode}
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, Nothing, Missing} = 
    hole_location == [] && cmn.children == [] ? (cmn.rule_ind, Dict()) : missing

# Matching Hole with MatchVar
_match_tree_containing_hole(::Hole, cmn::MatchVar, hole_location::Vector{Int}, ::Dict{Symbol, RuleNode}
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, Nothing, Missing} =
    hole_location == [] ? (cmn.var_name, Dict()) : missing


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
            varsᵢ ≡ missing && return missing

            # Update variables and check if another instance has a different assignment
            if !_update_variables!(vars, varsᵢ)
                return nothing
            end
        end
        return vars
    end
end

# Matching RuleNode with MatchVar
_match_tree(rn::RuleNode, cmn::MatchVar)::Union{Dict{Symbol, RuleNode}, Nothing, Missing} = Dict(cmn.var_name => rn)

# Matching Hole
_match_tree(h::Hole, rn::RuleNode)::Union{Dict{Symbol, RuleNode}, Nothing, Missing} = h.domain[rn.ind] ? missing : nothing
_match_tree(::Hole, ::AbstractMatchNode)::Union{Dict{Symbol, RuleNode}, Nothing, Missing} = missing


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
                domain ≡ missing && return missing
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
    return missing
end

_get_domain_from_rulenodes(::AbstractRuleNode, ::Hole) = missing


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
