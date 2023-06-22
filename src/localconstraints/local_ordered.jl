"""
Enforces an order over two or more subtrees that fill the variables 
specified in `order` when the pattern is applied at the location given by `path`.
Use an `Ordered` constraint for enforcing this throughout the entire search space.
"""
mutable struct LocalOrdered <: LocalConstraint
    path::Vector{Int}
    tree::AbstractMatchNode
    order::Vector{Symbol}
end

"""
Propagates the LocalOrdered constraint.
It removes rules from the domain that would violate the order of variables as defined in the 
constraint.
"""
function propagate(
    c::LocalOrdered, 
    ::Grammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{PropagatedDomain, Set{LocalConstraint}}
    # Skip the propagator if a node is being propagated that it isn't targeting
    if length(c.path) > length(context.nodeLocation) || c.path ≠ context.nodeLocation[1:length(c.path)]
        global prop_skip_local_count += 1
        return unchanged_domain, Set([c])
    end

    # Skip the propagator if the filled hole wasn't part of the path
	if !isnothing(filled_hole) && (length(c.path) > length(filled_hole.path) || c.path ≠ filled_hole.path[1:length(c.path)])
        global prop_skip_local_count += 1
		return unchanged_domain, Set([c])
	end

    global prop_local_count += 1

    n = get_node_at_location(context.originalExpr, c.path)

    hole_location = context.nodeLocation[length(c.path)+1:end]

    vars = Dict{Symbol, AbstractRuleNode}()

    match = _pattern_match_with_hole(n, c.tree, hole_location, vars)
    if match ≡ hardfail
        # Match attempt failed due to mismatched rulenode indices. 
        # This means that we can remove the current constraint.
        return unchanged_domain, Set()
    elseif match ≡ softfail
        # Match attempt failed because we had to compare with a hole. 
        # If the hole would've been filled it might have succeeded, so we cannot yet remove the constraint.
        return unchanged_domain, Set([c])
    else
        hole_var = nothing
        hole_path::Vector{Int} = []
        if match isa Tuple{Symbol, Vector{Int}}
            hole_var, hole_path = match
        end
        @assert hole_var ∈ keys(vars)
        @assert hole_var ∈ c.order

        hole_index = findfirst(isequal(hole_var), c.order) 

        for var ∈ c.order[1:hole_index-1]
            new_domain = make_greater_or_equal(vars[hole_var], vars[var], domain, hole_path)
            new_domain ≡ softfail && continue
            domain = new_domain
        end

        for var ∈ c.order[hole_index+1:end]
            new_domain = make_smaller_or_equal(vars[hole_var], vars[var], domain, hole_path)
            new_domain ≡ softfail && continue
            domain = new_domain
        end
    end

    return domain, Set()
end

function make_smaller_or_equal(
    rn₁::RuleNode, 
    rn₂::RuleNode, 
    domain::Vector{Int}, 
    hole_location::Vector{Int}
)::Union{Vector{Int}, MatchFail}

    if rn₁.ind < rn₂.ind
        return domain
    elseif rn₁.ind > rn₂.ind
        return Int[]
    else
        # rn₁.ind == rn₂.ind
        for (i, (c₁, c₂)) ∈ enumerate(zip(rn₁.children, rn₂.children))
            if i == hole_location[1]
                return make_smaller_or_equal(c₁, c₂, domain, hole_location[2:end])
            else
                comparison_value = _rulenode_compare(c₁, c₂)
                comparison_value ≡ softfail && return softfail
                if comparison_value == -1       # c₁ < c₂
                    return domain
                elseif comparison_value == 1    # c₁ > c₂
                    return Int[]
                end
            end
        end
    end
end

function make_smaller_or_equal(
    ::Hole, 
    ::RuleNode, 
    ::Vector{Int}, 
    ::Vector{Int}
)::Union{Vector{Int}, MatchFail}
    return softfail
end

function make_smaller_or_equal(
    h::Hole, 
    rn::RuleNode, 
    domain::Vector{Int}, 
    hole_location::Vector{Int}
)::Union{Vector{Int}, MatchFail}
    @assert hole_location == []
    return filter(x -> x ≤ rn.ind, domain)
end


function make_greater_or_equal(
    h₁::Hole, 
    h₂::Hole,
    domain::Vector{Int},
    hole_location::Vector{Int}
)::Union{Vector{Int}, MatchFail}
    @assert hole_location == []
    m = maximum(findall(h₂.domain))
    return filter(x → x ≤ m, domain)
end


function make_greater_or_equal(
    rn₁::RuleNode, 
    rn₂::RuleNode, 
    domain::Vector{Int}, 
    hole_location::Vector{Int}
)::Union{Vector{Int}, MatchFail}

    if rn₁.ind > rn₂.ind
        return domain
    elseif rn₁.ind < rn₂.ind
        return Int[]
    else
        # rn₁.ind == rn₂.ind
        for (i, (c₁, c₂)) ∈ enumerate(zip(rn₁.children, rn₂.children))
            if i == hole_location[1]
                return make_greater_or_equal(c₁, c₂, domain, hole_location[2:end])
            else
                comparison_value = _rulenode_compare(c₁, c₂)
                comparison_value ≡ softfail && return softfail
                if comparison_value == 1        # c₁ > c₂
                    return domain
                elseif comparison_value == -1   # c₁ < c₂
                    return Int[]
                end
            end
        end
    end
end

function make_greater_or_equal(
    ::Hole, 
    ::RuleNode, 
    ::Vector{Int}, 
    ::Vector{Int}
)::Union{Vector{Int}, MatchFail}
    return softfail
end

function make_greater_or_equal(
    h::Hole, 
    rn::RuleNode, 
    domain::Vector{Int}, 
    hole_location::Vector{Int}
)::Union{Vector{Int}, MatchFail}
    @assert hole_location == []

    return filter(x -> x ≥ rn.ind, domain)
end

function make_larger_or_equal(
    h₁::Hole, 
    h₂::Hole,
    domain::Vector{Int},
    hole_location::Vector{Int}
)::Union{Vector{Int}, MatchFail}
    @assert hole_location == []
    m = maximum(findall(h₂.domain))
    return filter(x → x ≤ m, domain)
end

"""
  - Returns -1 if rn₁ < rn₂
  - Returns  0 if rn₁ == rn₂  
  - Returns  1 if rn₁ > rn₂
"""
function _rulenode_compare(rn₁::RuleNode, rn₂::RuleNode)::Union{Int, MatchFail}
    if rn₁.ind == rn₂.ind
        for (c₁, c₂) ∈ zip(rn₁.children, rn₂.children)
            comparison = _rulenode_compare(c₁, c₂)
            comparison ≡ softfail && return softfail
            if comparison ≠ 0
                return comparison
            end
        end
        return 0
    else
        return rn₁.ind < rn₂.ind ? -1 : 1
    end
end

# TODO: Can we analyze the hole domains?
_rulenode_compare(::Hole, ::RuleNode) = softfail
_rulenode_compare(::RuleNode, ::Hole) = softfail
_rulenode_compare(::Hole, ::Hole) = softfail