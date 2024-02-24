abstract type PatternMatchResult end

"""
The pattern is exactly matched and does not involve any holes at all
"""
struct PatternMatchSuccess <: PatternMatchResult
end

"""
The pattern can be matched when the `hole` is filled with the given `ind`
"""
struct PatternMatchSuccessWhenHoleAssignedTo <: PatternMatchResult
    hole::Hole
    ind::Int
end

"""
The pattern is not matched or can never be matched by filling in holes
"""
struct PatternMatchHardFail <: PatternMatchResult
end

"""
The pattern can still be matched in a non-trivial way. Includes two cases:
- multiple holes are involved. this result stores a reference to one of them
- a single hole is involved, but needs to be filled with a node of size >= 2
"""
struct PatternMatchSoftFail <: PatternMatchResult
    hole::Hole
end

pattern_match(rn::AbstractRuleNode, mn::AbstractMatchNode) = pattern_match(rn, mn, Dict{Symbol, AbstractRuleNode}())

"""
    pattern_match(rn::RuleNode, mn::MatchNode, vars::Dict{Symbol, AbstractRuleNode})::Union{Nothing, MatchFail}  

Tries to match [`RuleNode`](@ref) `rn` with [`MatchNode`](@ref) `mn`.
Modifies the variable assignment dictionary `vars`.
Returns a `PatternMatchResult` that describes if the pattern was matched.
"""
function pattern_match(rn::RuleNode, mn::MatchNode, vars::Dict{Symbol, AbstractRuleNode})::PatternMatchResult
    if rn.ind ≠ mn.rule_ind
        return PatternMatchHardFail()
    end
    return pattern_match(rn.children, mn.children, vars)
end

function pattern_match(h::VariableShapedHole, mn::MatchNode, ::Dict{Symbol, AbstractRuleNode})::PatternMatchResult
    if !h.domain[mn.rule_ind]
        return PatternMatchHardFail()
    end
    if isempty(mn.children)
        return PatternMatchSuccessWhenHoleAssignedTo(h, mn.rule_ind)
    end
    #a large hole is involved
    return PatternMatchSoftFail(h)
end

function pattern_match(h::FixedShapedHole, mn::MatchNode, vars::Dict{Symbol, AbstractRuleNode})::PatternMatchResult
    if !h.domain[mn.rule_ind]
        return PatternMatchHardFail()
    end
    match_result = pattern_match(h.children, mn.children, vars)
    @match match_result begin
        ::PatternMatchHardFail => return match_result;
        ::PatternMatchSoftFail => return match_result;
        ::PatternMatchSuccess => return PatternMatchSuccessWhenHoleAssignedTo(h, mn.rule_ind);
        ::PatternMatchSuccessWhenHoleAssignedTo => return PatternMatchSoftFail(match_result.hole);
    end
end

function pattern_match(rns::Vector{AbstractRuleNode}, mns::Vector{AbstractMatchNode}, vars::Dict{Symbol, AbstractRuleNode})::PatternMatchResult
    if length(rns) ≠ length(mns)
        return PatternMatchHardFail()
    end
    match_result = PatternMatchSuccess()
    for child_match_result ∈ map(ab -> pattern_match(ab[1], ab[2], vars), zip(rns, mns))
        @match child_match_result begin
            ::PatternMatchHardFail => return child_match_result;
            ::PatternMatchSoftFail => return child_match_result;
            ::PatternMatchSuccess => ();
            ::PatternMatchSuccessWhenHoleAssignedTo => begin
                if !(match_result isa PatternMatchSuccess)
                    return PatternMatchSoftFail(child_match_result.hole)
                end
                match_result = child_match_result;
            end
        end
    end
    return match_result
end

# """
#     _pattern_match(rn::RuleNode, mv::MatchVar, vars::Dict{Symbol, AbstractRuleNode})::Union{Nothing, MatchFail}

# Matching [`RuleNode`](@ref) `rn` with [`MatchVar`](@ref) `mv`. If the variable is already assigned, the rulenode is matched with the specific variable value. 
# If the match is unsuccessful, it returns whether it is a softfail or hardfail (see [`MatchFail`](@ref) docstring)
# """
# function pattern_match(rn::RuleNode, mv::MatchVar, vars::Dict{Symbol, AbstractRuleNode})::PatternMatchResult
#     if mv.var_name ∈ keys(vars) 
#         # If the assignments are unequal, the match is unsuccessful
#         # Additionally, if the trees are equal but contain a hole, 
#         # we cannot reason about equality because we don't know how
#         # the hole will be expanded yet.
#         if contains_hole(rn) || contains_hole(vars[mv.var_name]) 
#             return softfail
#         else
#             return _rulenode_match(rn, vars[mv.var_name])
#         end
#     else
#         vars[mv.var_name] = rn
#     end
#     return PatternMatchSuccess()
# end

# function pattern_match(::Hole, ::MatchVar, ::Dict{Symbol, AbstractRuleNode})::Union{Nothing, MatchFail, Vector{HoleAssignment}}
#     throw("NotImplementedException")
#     return PatternMatchHardFail()
# end
