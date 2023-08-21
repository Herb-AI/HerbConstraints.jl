
"""
    _rulenode_match_with_hole(rn₁::RuleNode, rn₂::RuleNode, hole_location::Vector{Int})::Union{Int, MatchFail}

Matches two rulenodes. 
Returns how to fill in the hole in rn₁ to make it match rn₂ if:
  - rn₁ has a single hole at the provided location
  - rn₂ doesn't have any holes
  - rn₁ matches rn₂ apart from the single hole location.
If the match fails, it returns whether it is a softfail or a hardfail (see MatchFail docstring)
"""
function _rulenode_match_with_hole(rn₁::RuleNode, rn₂::RuleNode, hole_location::Vector{Int})::Union{Int, MatchFail}
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

function _rulenode_match_with_hole(::Hole, rn₂::RuleNode, hole_location::Vector{Int})::Union{Int, MatchFail}
    if hole_location == [] && rn₂.children == []
        return rn₂.ind
    end
    return softfail
end

_rulenode_match_with_hole(rn::RuleNode, h::Hole)::Union{Int, MatchFail} = h.domain[rn.ind] ? softfail : hardfail

# TODO: It might be worth checking if domains don't overlap and getting a hardfail 
_rulenode_match_with_hole(::Hole, ::Hole)::Union{Int, MatchFail} = softfail

function _rulenode_match(rn₁::RuleNode, rn₂::RuleNode)::Union{Nothing, MatchFail}
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

_rulenode_match(rn::RuleNode, h::Hole)::Union{Nothing, MatchFail} = h.domain[rn.ind] ? softfail : hardfail
_rulenode_match(h::Hole, rn::RuleNode)::Union{Nothing, MatchFail} = h.domain[rn.ind] ? softfail : hardfail
# TODO: It might be worth checking if domains don't overlap and getting a hardfail 
_rulenode_match(::Hole, ::Hole)::Union{Nothing, MatchFail} = softfail
