"""
Forbids the subtree to be generated.
A subtree is defined as a tree of `AbstractConstraintMatchNode`s. 
Such a node can either be a `ConstraintMatchNode`, which contains a rule index corresponding to the 
rule index in the grammar of the rulenode we are trying to match.
It can also contain a `ConstraintMatchVar`, which contains a single identifier symbol.
"""
struct ForbiddenTree <: PropagatorConstraint
	tree::AbstractConstraintMatchNode
end

containshole(rn::RuleNode) = any(containsHole(c) for c ∈ rn.children)
containshole(::Hole) = true


# Matching RuleNode with ConstraintMatchNode
"""
Tries to match RuleNode `rn` with ConstraintMatchNode `cmn` and fill in 
the domain of the hole at `hole_location`. 
Returns if match is successful:

- A dictionary with variable assignments
- The id for the node which fills the hole
A variable is represented by the index of its rulenode.
Returns nothing if the match is unsuccessful.
"""
function _match_expr_with_hole(
    rn::RuleNode, 
    cmn::ConstraintMatchNode, 
    hole_location::Vector{Int}
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, Nothing}
    hole_location == [] && throw(ArgumentError("The hole location doesn't point to a hole!"))

    if rn.ind ≠ cmn.rule_ind || length(rn.children) ≠ length(cmn.children)
        return nothing
    else
        vars = Dict()
        forbidden_domain = nothing
        for (i, rnᵢ, cmnᵢ) ∈ zip(1:length(rn.children), rn.children, cmn.children)
            if i == hole_location[1]
                # Match with finding domain of hole
                match = _match_expr_with_hole(rnᵢ, cmnᵢ, hole_location[begin+1:end])
                if match ≡ nothing
                    # unsuccessful match
                    return nothing
                end
                forbidden_domain, varsᵢ = match
            else
                # Regular match
                varsᵢ = _match_expr(rnᵢ, cmnᵢ)
                if varsᵢ ≡ nothing
                    # unsuccessful match
                    return nothing
                end
            end

            # Check if another argument already assigned the same variables
            for (k, v) ∈ varsᵢ
                if k ∈ keys(vars) 
                    # If the assignments are unequal, the match is unsuccessful
                    # Additionally, if the trees are equal but contain a hole, 
                    # we cannot reason about equality because we don't know how
                    # the hole will be expanded yet.
                    if v ≠ vars[k] || containshole(v)
                        return nothing
                    end
                end
                vars[k] = v
            end
        end
        return forbidden_domain, vars
    end
end

# Matching RuleNode with ConstraintMatchVar
function _match_expr_with_hole(
    ::RuleNode, 
    ::ConstraintMatchVar, 
    ::Vector{Int}
)::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, Nothing}
    return nothing
end

# Matching Hole with ConstraintMatchNode
function _match_expr_with_hole(
    ::Hole, 
    cmn::ConstraintMatchNode, 
    hole_location::Vector{Int}
 )::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, Nothing}
    if hole_location == [] && cmn.children == []
        return cmn.rule_ind, Dict()
    end
    return nothing
end

# Matching Hole with ConstraintMatchVar
function _match_expr_with_hole(
    ::Hole, 
    cmn::ConstraintMatchVar, 
    hole_location::Vector{Int}
 )::Union{Tuple{Union{Int, Symbol}, Dict{Symbol, RuleNode}}, Nothing}
    if hole_location == []
        return cmn.var_name, Dict()
    end
    return nothing
end

# Matching RuleNode with ConstraintMatchNode
"""
Tries to match RuleNode `rn` with ConstraintMatchNode `cmn`.
Returns a dictionary of values assigned to variables if the match is successful.
"""
function _match_expr(rn::RuleNode, cmn::ConstraintMatchNode)::Union{Dict{Symbol, RuleNode}, Nothing}
    if rn.ind ≠ cmn.rule_ind || length(rn.children) ≠ length(cmn.children)
        return nothing
    else
        # Root nodes match, now we check the child nodes
        vars = Dict()
        for varsᵢ ∈ map(ab -> _match_expr(ab[1], ab[2]), zip(rn.children, cmn.children)) 
            if varsᵢ ≡ nothing 
                # unsuccessful match
                return nothing
            end
            # Check if another argument already assigned the same variables
            for (k, v) ∈ varsᵢ
                if k ∈ keys(vars) && v ≠ vars[k]
                    return nothing
                end
                vars[k] = v
            end
        end
        return vars
    end
end

# Matching RuleNode with ConstraintMatchVar
_match_expr(rn::RuleNode, cmn::ConstraintMatchVar)::Union{Dict{Symbol, RuleNode}, Nothing} = Dict(cmn.var_name => rn)

# Matching Hole
_match_expr(::Hole, ::AbstractConstraintMatchNode)::Union{Dict{Symbol, RuleNode}, Nothing} = nothing

"""
Retrieves a rulenode at the original location by reference. 
"""
function get_node_at_location(root::RuleNode, location::Vector{Int})
    if location == []
        return root
    else
        return get_node_at_location(root.children[location[1]], location[2:end])
    end
end

function get_node_at_location(root::Hole, location::Vector{Int})
    if location == []
        return root
    end
    return nothing
end


"""
Propagates the ForbiddenTree constraint.
It removes the elements from the domain that would complete the forbidden tree.
"""
function propagate(c::ForbiddenTree, ::Grammar, context::GrammarContext, domain::Vector{Int})
    for i ∈ 0:length(context.nodeLocation)
        n = get_node_at_location(context.originalExpr, context.nodeLocation[1:i])
        match = _match_expr_with_hole(n, c.tree, context.nodeLocation[i+1:end])
        
        # Try to match the parent in the next level if there is no match
        if match ≡ nothing
            continue
        end

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
                # This is too specific to reduce the domain
                continue
            end
        elseif domain_match isa Int
            # The domain match is an actual (terminal) rule
            remove_from_domain = domain_match
        end

        # Remove the rule that would complete the forbidden tree from the domain
        loc = findfirst(isequal(remove_from_domain), domain)
        if loc !== nothing
            deleteat!(domain, loc)
        end


        if domain == []
            return []
        end
    end
    return domain
end
