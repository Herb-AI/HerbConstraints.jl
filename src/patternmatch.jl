"""
    abstract type PatternMatchResult end

A result of the `pattern_match` function. Can be one of 4 cases:
- [`PatternMatchSuccess`](@ref)
- [`PatternMatchSuccessWhenHoleAssignedTo`](@ref)
- [`PatternMatchHardFail`](@ref)
- [`PatternMatchSoftFail`](@ref)
"""
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
The pattern is not matched and can never be matched by filling in holes
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

"""
    pattern_match(rn::AbstractRuleNode, mn::AbstractRuleNode)::PatternMatchResult

Recursively tries to match [`AbstractRuleNode`](@ref) `rn` with [`AbstractRuleNode`](@ref) `mn`.
Returns a `PatternMatchResult` that describes if the pattern was matched.
"""
function pattern_match(rn::AbstractRuleNode, mn::AbstractRuleNode)::PatternMatchResult
    pattern_match(rn, mn, Dict{Symbol, AbstractRuleNode}())
end

"""
Generic fallback function for commutativity. Swaps arguments 1 and 2, then dispatches to a more specific signature.
If this gets stuck in an infinite loop, the implementation of an AbstractRuleNode type pair is missing.
"""
function pattern_match(mn::AbstractRuleNode, rn::AbstractRuleNode, vars::Dict{Symbol, AbstractRuleNode})
    pattern_match(rn, mn, vars)
end

"""
    pattern_match(rns::Vector{AbstractRuleNode}, mns::Vector{AbstractRuleNode}, vars::Dict{Symbol, AbstractRuleNode})::PatternMatchResult

Pairwise tries to match two ordered lists of [AbstractRuleNode](@ref)s.
"""
function pattern_match(rns::Vector{AbstractRuleNode}, mns::Vector{AbstractRuleNode}, vars::Dict{Symbol, AbstractRuleNode})::PatternMatchResult
    if length(rns) ≠ length(mns)
        return PatternMatchHardFail()
    end
    match_result = PatternMatchSuccess()
    for child_match_result ∈ map(tup -> pattern_match(tup[2][1], tup[2][2], vars), enumerate(zip(rns, mns)))
        @match child_match_result begin
            ::PatternMatchHardFail => return child_match_result;
            ::PatternMatchSoftFail => (match_result = child_match_result); #continue searching for a hardfail
            ::PatternMatchSuccess => (); #continue searching for a hardfail
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

function pattern_match(rn::RuleNode, mn::RuleNode, vars::Dict{Symbol, AbstractRuleNode})::PatternMatchResult
    if get_rule(rn) ≠ get_rule(mn)
        return PatternMatchHardFail()
    end
    return pattern_match(rn.children, mn.children, vars)
end

function pattern_match(h::VariableShapedHole, mn::RuleNode, vars::Dict{Symbol, AbstractRuleNode})::PatternMatchResult
    if !h.domain[get_rule(mn)]
        return PatternMatchHardFail()
    end
    if isempty(mn.children)
        return PatternMatchSuccessWhenHoleAssignedTo(h, get_rule(mn))
    end
    #a large hole is involved
    return PatternMatchSoftFail(h)
end

function pattern_match(h::FixedShapedHole, mn::RuleNode, vars::Dict{Symbol, AbstractRuleNode})::PatternMatchResult
    if !h.domain[get_rule(mn)]
        return PatternMatchHardFail()
    end
    match_result = pattern_match(h.children, mn.children, vars)
    @match match_result begin
        ::PatternMatchHardFail => return match_result;
        ::PatternMatchSoftFail => return match_result;
        ::PatternMatchSuccess => return PatternMatchSuccessWhenHoleAssignedTo(h, get_rule(mn));
        ::PatternMatchSuccessWhenHoleAssignedTo => return PatternMatchSoftFail(match_result.hole);
    end
end

function pattern_match(h1::FixedShapedHole, h2::FixedShapedHole, vars::Dict{Symbol, AbstractRuleNode})::PatternMatchResult
    if are_disjoint(h1.domain, h2.domain)
        return PatternMatchHardFail()
    end
    match_result = pattern_match(h1.children, h2.children, vars)
    @match match_result begin
        ::PatternMatchHardFail => return match_result;
        ::PatternMatchSoftFail => return match_result;
        ::PatternMatchSuccess => return PatternMatchSoftFail(h1);
        ::PatternMatchSuccessWhenHoleAssignedTo => return PatternMatchSoftFail(match_result.hole);
    end
end

function pattern_match(h1::VariableShapedHole, h2::FixedShapedHole, vars::Dict{Symbol, AbstractRuleNode})::PatternMatchResult
    if are_disjoint(h1.domain, h2.domain)
        return PatternMatchHardFail()
    end
    return PatternMatchSoftFail(h1);
end

function pattern_match(h1::VariableShapedHole, h2::VariableShapedHole, vars::Dict{Symbol, AbstractRuleNode})::PatternMatchResult
    if are_disjoint(h1.domain, h2.domain)
        return PatternMatchHardFail()
    end
    return PatternMatchSoftFail(h1);
end

function pattern_match(rn::AbstractRuleNode, var::VarNode, vars::Dict{Symbol, AbstractRuleNode})::PatternMatchResult
    if var.name ∈ keys(vars) 
        return pattern_match(rn, vars[var.name])
    end
    vars[var.name] = rn
    return PatternMatchSuccess()
end


#TODO: all `pattern_match` functions for `StateFixedShapedHole`s are untested and copied from similar cases
#TODO: refactor the entire family of `pattern_match` functions to be more type resilient
#TODO: write unit tests for pattern matches with `StateFixedShapedHole`

function pattern_match(h1::Union{StateFixedShapedHole, RuleNode}, h2::Union{StateFixedShapedHole, RuleNode}, vars::Dict{Symbol, AbstractRuleNode})
    @match (isfilled(h1), isfilled(h2)) begin
        (true, true) => begin
            #pattern match like rulenodes
            if get_rule(h1) ≠ get_rule(h2)
                return PatternMatchHardFail()
            end
            return pattern_match(h1.children, h2.children, vars)
        end
        (true, false) => begin
            if !h2.domain[get_rule(h1)]
                return PatternMatchHardFail()
            end
            match_result = pattern_match(h1.children, h2.children, vars)
            @match match_result begin
                ::PatternMatchHardFail => return match_result;
                ::PatternMatchSoftFail => return match_result;
                ::PatternMatchSuccess => return PatternMatchSuccessWhenHoleAssignedTo(h2, get_rule(h1));
                ::PatternMatchSuccessWhenHoleAssignedTo => return PatternMatchSoftFail(match_result.hole);
            end
        end
        (false, true) => begin
            if !h1.domain[get_rule(h2)]
                return PatternMatchHardFail()
            end
            match_result = pattern_match(h1.children, h2.children, vars)
            @match match_result begin
                ::PatternMatchHardFail => return match_result;
                ::PatternMatchSoftFail => return match_result;
                ::PatternMatchSuccess => return PatternMatchSuccessWhenHoleAssignedTo(h1, get_rule(h2));
                ::PatternMatchSuccessWhenHoleAssignedTo => return PatternMatchSoftFail(match_result.hole);
            end
        end
        (false, false) => begin
            if are_disjoint(h1.domain, h2.domain)
                return PatternMatchHardFail()
            end
            match_result = pattern_match(h1.children, h2.children, vars)
            @match match_result begin
                ::PatternMatchHardFail => return match_result;
                ::PatternMatchSoftFail => return match_result;
                ::PatternMatchSuccess => return PatternMatchSoftFail(h1);
                ::PatternMatchSuccessWhenHoleAssignedTo => return PatternMatchSoftFail(match_result.hole);
            end
        end
    end
end
