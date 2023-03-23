
"""
Tries to match RuleNode `rn` with MatchNode `mn` and fill in 
the domain of the hole at `hole_location`. 
Returns if match is successful:
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
    mn::MatchNode, 
    hole_location::Vector{Int},
    vars::Dict{Symbol, RuleNode}
)::Union{Int, Symbol, MatchFail}
    hole_location == [] && throw(ArgumentError("The hole location doesn't point to a hole!"))

    if rn.ind ≠ mn.rule_ind || length(rn.children) ≠ length(mn.children)
        return hardfail
    else
        child_tuples = collect(zip(rn.children, mn.children))

        softfailed = false
        # Match all children that aren't part of the path to the hole
        for (rnᵢ, cmnᵢ) ∈ Iterators.flatten((child_tuples[1:hole_location[1]-1], child_tuples[hole_location[1]+1:end]))
            match = _pattern_match(rnᵢ, cmnᵢ, vars)
            # Immediately return if we didn't get a match
            match ≡ hardfail && return hardfail
            # TODO: Continue searching to try to find a hardfail? 
            if match ≡ softfail
                softfailed = true
            end
        end

        # Match the child that is on the path to the hole. 
        # Doing this in after all other children makes sure all variables are assigned when the hole is matched.
        rnᵢ = rn.children[hole_location[1]]
        cmnᵢ = mn.children[hole_location[1]]
        match = _pattern_match_with_hole(rnᵢ, cmnᵢ, hole_location[begin+1:end], vars)

        # Immediately return if we didn't get a match
        match ≡ hardfail && return hardfail
        match ≡ softfail && return softfail
        softfailed && return softfail

        return match
    end
end

# Matching RuleNode with MatchVar
function _pattern_match_with_hole(
    rn::RuleNode, mv::MatchVar, 
    hole_location::Vector{Int}, 
    vars::Dict{Symbol, RuleNode}
)::Union{Int, Symbol, MatchFail}
    if mv.var_name ∈ keys(vars)
        return _rulenode_match_with_hole(rn, vars[mv.var_name], hole_location)
    end
    # 0 is the special case for matching any rulenode.
    # This is the case if the hole matches an unassigned variable (wildcard).
    return 0
end

# Matching Hole with MatchNode
_pattern_match_with_hole(::Hole, mn::MatchNode, hole_location::Vector{Int}, ::Dict{Symbol, RuleNode}
)::Union{Int, Symbol, MatchFail} = 
    hole_location == [] && mn.children == [] ? mn.rule_ind : softfail

# Matching Hole with MatchVar
_pattern_match_with_hole(::Hole, mv::MatchVar, hole_location::Vector{Int}, ::Dict{Symbol, RuleNode}
)::Union{Int, Symbol, MatchFail} =
    hole_location == [] ? mv.var_name : softfail


# Matching RuleNode with MatchNode
"""
Tries to match RuleNode `rn` with MatchNode `mn`.
Modifies the variable assignment dictionary `vars`.
Returns nothing if the match is successful.
If the match is unsuccessful, it returns whether it 
is a softfail or hardfail (see MatchFail docstring)
"""
function _pattern_match(rn::RuleNode, mn::MatchNode, vars::Dict{Symbol, RuleNode})::Union{Nothing, MatchFail}  
    if rn.ind ≠ mn.rule_ind || length(rn.children) ≠ length(mn.children)
        return hardfail
    else
        # Root nodes match, now we check the child nodes
        softfailed = false
        for varsᵢ ∈ map(ab -> _pattern_match(ab[1], ab[2], vars), zip(rn.children, mn.children)) 
            # Immediately return if we didn't get a match
            varsᵢ ≡ hardfail && return hardfail
            varsᵢ ≡ softfail && (softfailed = true)
        end
        softfailed && return softfail
    end
    return nothing
end

# Matching RuleNode with MatchVar
function _pattern_match(rn::RuleNode, mv::MatchVar, vars::Dict{Symbol, RuleNode})::Union{Nothing, MatchFail}
    if mv.var_name ∈ keys(vars) 
        # If the assignments are unequal, the match is unsuccessful
        # Additionally, if the trees are equal but contain a hole, 
        # we cannot reason about equality because we don't know how
        # the hole will be expanded yet.
        if contains_hole(rn) || contains_hole(vars[mv.var_name]) 
            return softfail
        else
            return _rulenode_match(rn, vars[mv.var_name])
        end
    else
        vars[mv.var_name] = rn
    end
    return nothing
end

# Matching Hole
_pattern_match(h::Hole, mn::MatchNode, ::Dict{Symbol, RuleNode})::Union{Nothing, MatchFail} = h.domain[mn.rule_ind] ? softfail : hardfail
_pattern_match(::Hole, ::MatchVar, ::Dict{Symbol, RuleNode})::Union{Nothing, MatchFail} = softfail
