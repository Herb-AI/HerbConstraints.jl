# # Deprecated

# """
#     _pattern_match_with_hole(rn::RuleNode, mn::MatchNode, hole_location::Vector{Int}, vars::Dict{Symbol, AbstractRuleNode})::Union{Int, Symbol, MatchFail, Tuple{Symbol, Vector{Int}}}

# Tries to match [`RuleNode`](@ref) `rn` with [`MatchNode`](@ref) `mn` and fill in the domain of the hole at `hole_location`. 
# Returns if match is successful either:
#   - The id for the node which fills the hole
#   - A symbol for the variable that fills the hole
#   - A tuple containing:
#     - The variable that matched (the subtree containing) the hole
#     - The location of the hole in this subtree

# If the match is unsuccessful, it returns:
#   - hardfail if there are no holes that can be filled in such a way that the match will become succesful
#   - softfail if the match could become successful if the holes are filled in a certain way
# """
# function _pattern_match_with_hole(
#     rn::RuleNode, 
#     mn::MatchNode, 
#     hole_location::Vector{Int},
#     vars::Dict{Symbol, AbstractRuleNode}
# )::Union{Int, Symbol, MatchFail, Tuple{Symbol, Vector{Int}}}
#     hole_location == [] && throw(ArgumentError("The hole location doesn't point to a hole!"))

#     if rn.ind ≠ mn.rule_ind || length(rn.children) ≠ length(mn.children)
#         return hardfail
#     else
#         child_tuples = collect(zip(rn.children, mn.children))

#         softfailed = false
#         # Match all children that aren't part of the path to the hole
#         for (rnᵢ, cmnᵢ) ∈ Iterators.flatten((child_tuples[1:hole_location[1]-1], child_tuples[hole_location[1]+1:end]))
#             match = _pattern_match(rnᵢ, cmnᵢ, vars)
#             # Immediately return if we didn't get a match
#             match ≡ hardfail && return hardfail
#             # TODO: Continue searching to try to find a hardfail? 
#             if match ≡ softfail
#                 softfailed = true
#             end
#         end

#         # Match the child that is on the path to the hole. 
#         # Doing this in after all other children makes sure all variables are assigned when the hole is matched.
#         rnᵢ = rn.children[hole_location[1]]
#         cmnᵢ = mn.children[hole_location[1]]
#         match = _pattern_match_with_hole(rnᵢ, cmnᵢ, hole_location[begin+1:end], vars)

#         # Immediately return if we didn't get a match
#         match ≡ hardfail && return hardfail
#         match ≡ softfail && return softfail
#         softfailed && return softfail

#         return match
#     end
# end

# """
#     _pattern_match_with_hole(rn::RuleNode, mv::MatchVar, hole_location::Vector{Int}, vars::Dict{Symbol, AbstractRuleNode})::Union{Int, Symbol, MatchFail, Tuple{Symbol, Vector{Int}}}

# Tries to match [`RuleNode`](@ref) `rn` with [`MatchVar`](@ref) `mv` and fill in the domain of the hole at `hole_location`.
# If the variable name is already assigned in `vars`, the rulenode is matched with the hole. Otherwise the variable and the hole location are returned.
# """
# function _pattern_match_with_hole(
#     rn::RuleNode, 
#     mv::MatchVar, 
#     hole_location::Vector{Int}, 
#     vars::Dict{Symbol, AbstractRuleNode}
# )::Union{Int, Symbol, MatchFail, Tuple{Symbol, Vector{Int}}}
#     if mv.var_name ∈ keys(vars)
#         return _rulenode_match_with_hole(rn, vars[mv.var_name], hole_location)
#     else
#         vars[mv.var_name] = rn
#         return (mv.var_name, hole_location)
#     end
# end

# """
#     _pattern_match_with_hole(::Hole, mn::MatchNode, hole_location::Vector{Int}, ::Dict{Symbol, AbstractRuleNode})::Union{Int, Symbol, MatchFail, Tuple{Symbol, Vector{Int}}} 

# Matches the [`Hole`](@ref) with the given [`MatchNode`](@ref). 

# TODO check this behaviour?
# """
# _pattern_match_with_hole(::Hole, mn::MatchNode, hole_location::Vector{Int}, ::Dict{Symbol, AbstractRuleNode}
# )::Union{Int, Symbol, MatchFail, Tuple{Symbol, Vector{Int}}} = 
#     hole_location == [] && mn.children == [] ? mn.rule_ind : softfail

# """
#     _pattern_match_with_hole(::Hole, mn::MatchNode, hole_location::Vector{Int}, ::Dict{Symbol, AbstractRuleNode})::Union{Int, Symbol, MatchFail, Tuple{Symbol, Vector{Int}}} 

# Matches the [`Hole`](@ref) with the given [`MatchVar`](@ref), similar to [`_pattern_match_with_hole`](@ref).
# """
# function _pattern_match_with_hole(h::Hole, mv::MatchVar, hole_location::Vector{Int}, vars::Dict{Symbol, AbstractRuleNode}
# )::Union{Int, Symbol, MatchFail, Tuple{Symbol, Vector{Int}}}
#     @assert hole_location == []
#     if mv.var_name ∈ keys(vars)
#         return _rulenode_match_with_hole(h, vars[mv.var_name], hole_location)
#     else
#         vars[mv.var_name] = h
#         return (mv.var_name, hole_location)
#     end
# end

# """
#     _pattern_match(rn::RuleNode, mn::MatchNode, vars::Dict{Symbol, AbstractRuleNode})::Union{Nothing, MatchFail}  

# Tries to match [`RuleNode`](@ref) `rn` with [`MatchNode`](@ref) `mn`.
# Modifies the variable assignment dictionary `vars`.
# Returns `nothing` if the match is successful.
# If the match is unsuccessful, it returns whether it is a softfail or hardfail (see [`MatchFail`](@ref) docstring)
# """
# function _pattern_match(rn::RuleNode, mn::MatchNode, vars::Dict{Symbol, AbstractRuleNode})::Union{Nothing, MatchFail}  
#     if rn.ind ≠ mn.rule_ind || length(rn.children) ≠ length(mn.children)
#         return hardfail
#     else
#         # Root nodes match, now we check the child nodes
#         softfailed = false
#         for varsᵢ ∈ map(ab -> _pattern_match(ab[1], ab[2], vars), zip(rn.children, mn.children)) 
#             # Immediately return if we didn't get a match
#             varsᵢ ≡ hardfail && return hardfail
#             varsᵢ ≡ softfail && (softfailed = true)
#         end
#         softfailed && return softfail
#     end
#     return nothing
# end

# """
#     _pattern_match(rn::RuleNode, mv::MatchVar, vars::Dict{Symbol, AbstractRuleNode})::Union{Nothing, MatchFail}

# Matching [`RuleNode`](@ref) `rn` with [`MatchVar`](@ref) `mv`. If the variable is already assigned, the rulenode is matched with the specific variable value. Returns `nothing` if the match is succesful. 
# If the match is unsuccessful, it returns whether it is a softfail or hardfail (see [`MatchFail`](@ref) docstring)
# """
# function _pattern_match(rn::RuleNode, mv::MatchVar, vars::Dict{Symbol, AbstractRuleNode})::Union{Nothing, MatchFail}
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
#     return nothing
# end

# # Matching Hole
# _pattern_match(h::Hole, mn::MatchNode, ::Dict{Symbol, AbstractRuleNode})::Union{Nothing, MatchFail} = h.domain[mn.rule_ind] ? softfail : hardfail
# _pattern_match(::Hole, ::MatchVar, ::Dict{Symbol, AbstractRuleNode})::Union{Nothing, MatchFail} = softfail
