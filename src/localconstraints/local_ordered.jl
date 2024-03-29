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
    ::AbstractGrammar, 
    context::GrammarContext, 
    domain::Vector{Int}, 
    filled_hole::Union{HoleReference, Nothing}
)::Tuple{PropagatedDomain, Set{LocalConstraint}}
    # Skip the propagator if a node is being propagated that it isn't targeting
    if length(c.path) > length(context.nodeLocation) || c.path ≠ context.nodeLocation[1:length(c.path)]
        return domain, Set([c])
    end

    # Skip the propagator if the filled hole wasn't part of the path
    if !isnothing(filled_hole) && (length(c.path) > length(filled_hole.path) || c.path ≠ filled_hole.path[1:length(c.path)])
      return domain, Set([c])
    end

    n = get_node_at_location(context.originalExpr, c.path)

    hole_location = context.nodeLocation[length(c.path)+1:end]

    vars = Dict{Symbol, AbstractRuleNode}()

    match = _pattern_match_with_hole(n, c.tree, hole_location, vars)
    if match ≡ hardfail
        # Match attempt failed due to mismatched rulenode indices. 
        # This means that we can remove the current constraint.
        return domain, Set()
    elseif match ≡ softfail
        # Match attempt failed because we had to compare with a hole. 
        # If the hole would've been filled it might have succeeded, so we cannot yet remove the constraint.
        return domain, Set([c])
    elseif match isa Tuple{Symbol, Vector{Int}}
        hole_var, hole_path = match

        @assert hole_var ∈ keys(vars)
        @assert hole_var ∈ c.order

        hole_index = findfirst(isequal(hole_var), c.order) 
        can_be_deleted = true
        for var ∈ c.order[1:hole_index-1]
            new_domain, can_be_deletedᵢ = make_greater_or_equal(vars[hole_var], vars[var], domain, hole_path)
            if !can_be_deletedᵢ 
                can_be_deleted = false
            end
            domain = new_domain
        end

        for var ∈ c.order[hole_index+1:end]
            new_domain, can_be_deletedᵢ = make_smaller_or_equal(vars[hole_var], vars[var], domain, hole_path)
            if !can_be_deletedᵢ 
                can_be_deleted = false
            end
            domain = new_domain
        end

        return domain, can_be_deleted ? Set() : Set([c])
    else
        @error("Unexpected result from pattern match, not propagating constraint $c")
        return domain, Set([c])
    end
end

"""
Filters the `domain` of the hole at `hole_location` in `rn₁` to make `rn₁` be ordered before `rn₂`.  
Returns the filtered domain, and a boolean indicating if this constraint can be deleted.
"""
function make_smaller_or_equal(
    rn₁::RuleNode, 
    rn₂::RuleNode, 
    domain::Vector{Int}, 
    hole_location::Vector{Int}
)::Tuple{Vector{Int}, Bool}

    if rn₁.ind < rn₂.ind
        return domain, true
    elseif rn₁.ind > rn₂.ind
        return Int[], true
    else
        # rn₁.ind == rn₂.ind
        for (i, (c₁, c₂)) ∈ enumerate(zip(rn₁.children, rn₂.children))
            if i == hole_location[1]
                return make_smaller_or_equal(c₁, c₂, domain, hole_location[2:end])
            else
                comparison_value = _rulenode_compare(c₁, c₂)
                comparison_value ≡ softfail && return domain, false
                if comparison_value == -1       # c₁ < c₂
                    return domain, true
                elseif comparison_value == 1    # c₁ > c₂
                    return Int[], true
                end
            end
        end
    end
end


function make_smaller_or_equal(
    h::Hole, 
    rn::RuleNode, 
    domain::Vector{Int}, 
    hole_location::Vector{Int}
)::Tuple{Vector{Int}, Bool}
    @assert hole_location == []
    return filter(x -> x ≤ rn.ind, domain), false
end

function make_smaller_or_equal(
    ::RuleNode, 
    ::Hole, 
    domain::Vector{Int}, 
    ::Vector{Int}
)::Tuple{Vector{Int}, Bool}
    return domain, false
end

function make_smaller_or_equal(
    ::Hole,
    ::Hole,
    domain::Vector{Int},
    hole_location::Vector{Int}
)::Tuple{Vector{Int}, Bool}
    @assert hole_location == []
    return domain, false
end


function make_greater_or_equal(
    rn₁::RuleNode, 
    rn₂::RuleNode, 
    domain::Vector{Int}, 
    hole_location::Vector{Int}
)::Tuple{Vector{Int}, Bool}

    if rn₁.ind > rn₂.ind
        return domain, true
    elseif rn₁.ind < rn₂.ind
        return Int[], true
    else
        # rn₁.ind == rn₂.ind
        for (i, (c₁, c₂)) ∈ enumerate(zip(rn₁.children, rn₂.children))
            if i == hole_location[1]
                return make_greater_or_equal(c₁, c₂, domain, hole_location[2:end])
            else
                comparison_value = _rulenode_compare(c₁, c₂)
                comparison_value ≡ softfail && return domain, false
                if comparison_value == 1        # c₁ > c₂
                    return domain, true
                elseif comparison_value == -1   # c₁ < c₂
                    return Int[], true
                end
            end
        end
    end
end

function make_greater_or_equal(
    h::Hole, 
    rn::RuleNode, 
    domain::Vector{Int}, 
    hole_location::Vector{Int}
)::Tuple{Vector{Int}, Bool}
    @assert hole_location == []
    return filter(x -> x ≥ rn.ind, domain), false
end

function make_greater_or_equal(
    ::RuleNode, 
    ::Hole, 
    ::Vector{Int}, 
    ::Vector{Int}
)::Tuple{Vector{Int}, Bool}
    return domain, false
end

function make_greater_or_equal(
    h₁::Hole, 
    h₂::Hole,
    domain::Vector{Int},
    hole_location::Vector{Int}
)::Tuple{Vector{Int}, Bool}
    @assert hole_location == []
    return domain, false
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
