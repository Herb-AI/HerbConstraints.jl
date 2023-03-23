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

@enum MatchFail hardfail softfail

"""
Propagates the ForbiddenTree constraint.
It removes the elements from the domain that would complete the forbidden tree.
"""
function propagate(c::ForbiddenTree, g::Grammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}
    notequals_constraint = NotEquals(context.nodeLocation, c.tree)
    new_domain, new_constraints = propagate(notequals_constraint, g, context, domain)
    return new_domain, new_constraints
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
If the match is unsuccessful, it returns:
  - hardfail if there are no holes that can be filled in such a way that the match will become succesful
  - softfail if the match could become succesful if the holes are filled in a certain way
"""
function _pattern_match_with_hole(
    rn::RuleNode, 
    cmn::MatchNode, 
    hole_location::Vector{Int},
    vars::Dict{Symbol, RuleNode}
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, MatchFail}
    hole_location == [] && throw(ArgumentError("The hole location doesn't point to a hole!"))

    if rn.ind ≠ cmn.rule_ind || length(rn.children) ≠ length(cmn.children)
        return hardfail
    else
        child_tuples = collect(zip(rn.children, cmn.children))

        # Match all children that aren't part of the path to the hole
        for (rnᵢ, cmnᵢ) ∈ Iterators.flatten((child_tuples[1:hole_location[1]-1], child_tuples[hole_location[1]+1:end]))
            varsᵢ = _pattern_match(rnᵢ, cmnᵢ)
            # Immediately return if we didn't get a match
            varsᵢ ≡ hardfail && return hardfail
            varsᵢ ≡ softfail && return softfail

            # Update variables and check if another instance has a different assignment
            variable_match = _update_variables!(vars, varsᵢ)
            if variable_match !== nothing
                return variable_match 
            end
        end

        # Match the child that is on the path to the hole. 
        # Doing this in after all other children makes sure all variables are assigned when the hole is matched.
        rnᵢ = rn.children[hole_location[1]]
        cmnᵢ = cmn.children[hole_location[1]]
        match = _pattern_match_with_hole(rnᵢ, cmnᵢ, hole_location[begin+1:end], vars)

        # Immediately return if we didn't get a match
        match ≡ hardfail && return hardfail
        match ≡ softfail && return softfail

        domain, varsᵢ = match
        # Update variables and check if another instance has a different assignment
        variable_match = _update_variables!(vars, varsᵢ)
        if variable_match !== nothing
            return variable_match 
        end
        return domain, vars
    end
end

# Matching RuleNode with MatchVar
function _pattern_match_with_hole(rn::RuleNode, cmn::MatchVar, hole_location::Vector{Int}, vars::Dict{Symbol, RuleNode}
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, MatchFail}
    if cmn.var_name ∈ keys(vars)
        match = _rulenode_match_with_hole(rn, vars[cmn.var_name], hole_location)
        match ≡ hardfail && return hardfail
        match ≡ softfail && return softfail
        return (match, Dict{Symbol, RuleNode}())
    end
    # 0 is the special case for matching any rulenode.
    # This is the case if the hole matches an unassigned variable (wildcard).
    return (0, Dict(cmn.var_name => rn))
end

# Matching Hole with MatchNode
_pattern_match_with_hole(::Hole, cmn::MatchNode, hole_location::Vector{Int}, ::Dict{Symbol, RuleNode}
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, MatchFail} = 
    hole_location == [] && cmn.children == [] ? (cmn.rule_ind, Dict()) : softfail

# Matching Hole with MatchVar
_pattern_match_with_hole(::Hole, cmn::MatchVar, hole_location::Vector{Int}, ::Dict{Symbol, RuleNode}
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, MatchFail} =
    hole_location == [] ? (cmn.var_name, Dict{Symbol, RuleNode}()) : softfail


# Matching RuleNode with MatchNode
"""
Tries to match RuleNode `rn` with MatchNode `cmn`.
Returns a dictionary of values assigned to variables if the match is successful.
"""
function _pattern_match(rn::RuleNode, cmn::MatchNode)::Union{Dict{Symbol, RuleNode}, MatchFail}  
    if rn.ind ≠ cmn.rule_ind || length(rn.children) ≠ length(cmn.children)
        return hardfail
    else
        # Root nodes match, now we check the child nodes
        vars::Dict{Symbol, RuleNode} = Dict()
        for varsᵢ ∈ map(ab -> _pattern_match(ab[1], ab[2]), zip(rn.children, cmn.children)) 
            # Immediately return if we didn't get a match
            varsᵢ ≡ hardfail && return hardfail
            varsᵢ ≡ softfail && return softfail

            # Update variables and check if another instance has a different assignment
            variable_match = _update_variables!(vars, varsᵢ)
            # If variable match returned either hard or soft fail
            if variable_match !== nothing 
                return variable_match 
            end
        end
        return vars
    end
end

# Matching RuleNode with MatchVar
_pattern_match(rn::RuleNode, cmn::MatchVar)::Union{Dict{Symbol, RuleNode}, MatchFail} = Dict(cmn.var_name => rn)

# Matching Hole
_pattern_match(h::Hole, rn::RuleNode)::Union{Dict{Symbol, RuleNode}, MatchFail} = h.domain[rn.ind] ? softfail : hardfail
_pattern_match(::Hole, ::AbstractMatchNode)::Union{Dict{Symbol, RuleNode}, MatchFail} = softfail


"""
Matches two rulenodes. 
Returns how to fill in the hole in rn₁ to make it match rn₂ if:
  - rn₁ has a single hole at the provided location
  - rn₂ doesn't have any holes
  - rn₁ matches rn₂ apart from the single hole location.
"""
function _rulenode_match_with_hole(rn₁::RuleNode, rn₂::RuleNode, hole_location::Vector{Int})
    if rn₁.ind ≠ rn₂.ind || hole_location == [] || length(rn₁.children) ≠ length(rn₂.children)
        return hardfail
    else
        domain = hardfail
        for (i, c₁, c₂) ∈ zip(Iterators.countfrom(), rn₁.children, rn₂.children)
            if i == hole_location[1]
                domain = _rulenode_match_with_hole(c₁, c₂, hole_location[2:end])
                # Immediately return if we didn't get a match
                domain ≡ hardfail && return hardfail
                domain ≡ softfail && return softfail
            else 
                rulenode_match = _rulenode_match(c₁, c₂)
                rulenode_match ≡ hardfail && return hardfail
                rulenode_match ≡ softfail && return softfail
            end
        end
        return domain
    end
end

function _rulenode_match_with_hole(::Hole, rn₂::RuleNode, hole_location::Vector{Int})
    if hole_location == [] && rn₂.children == []
        return rn₂.ind
    end
    return softfail
end

_rulenode_match_with_hole(rn::RuleNode, h::Hole) = h.domain[rn.ind] ? softfail : hardfail

# TODO: It might be worth checking if domains don't overlap and getting a hardfail 
_rulenode_match_with_hole(::Hole, ::Hole) = softfail

function _rulenode_match(rn₁::RuleNode, rn₂::RuleNode)
    if rn₁.ind ≠ rn₂.ind || length(rn₁.children) ≠ length(rn₂.children)
        return hardfail
    else
        for (c₁, c₂) ∈ zip(rn₁.children, rn₂.children)
            rulenode_match = _rulenode_match(c₁, c₂)
            rulenode_match ≡ hardfail && return hardfail
            rulenode_match ≡ softfail && return softfail

        end
    end
end

_rulenode_match(rn::RuleNode, h::Hole) = h.domain[rn.ind] ? softfail : hardfail
_rulenode_match(h::Hole, rn::RuleNode) = h.domain[rn.ind] ? softfail : hardfail
# TODO: It might be worth checking if domains don't overlap and getting a hardfail 
_rulenode_match(::Hole, ::Hole) = softfail

"""
Updates the existing variables with the new variables.
Returns true if there are no conflicting assignments.
"""
@inline function _update_variables!(existing_vars::Dict{Symbol, RuleNode}, new_vars::Dict{Symbol, RuleNode})::Union{MatchFail, Nothing}
    for (k, v) ∈ new_vars

        if k ∈ keys(existing_vars) 
            # If the assignments are unequal, the match is unsuccessful
            # Additionally, if the trees are equal but contain a hole, 
            # we cannot reason about equality because we don't know how
            # the hole will be expanded yet.
            if contains_hole(v) || contains_hole(existing_vars[k]) 
                return softfail
            elseif v ≠ existing_vars[k]
                return hardfail
            end
        end
        existing_vars[k] = v
    end
    return
end
