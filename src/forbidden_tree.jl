"""
Forbids the subtree to be generated.
Doesn't support variables yet.
"""
struct ForbiddenTree <: PropagatorConstraint
	tree::AbstractConstraintMatchNode
end

"""
Tries to match RuleNode rn with ConstraintMatchNode cmn. 
Returns if match is successful:
    - A dictionary with variable assignments
    - The id for the node which fills the hole
A variable is represented by the index of its rulenode.
Returns nothing if the match is unsuccessful.
"""
function _match_expr(
    rn::RuleNode, 
    cmn::AbstractConstraintMatchNode, 
    hole_location::Vector{Int}
)::Tuple{Union{Int, Symbol, Nothing}, Union{Dict{Symbol, RuleNode}, Nothing}}
    hole_location == [] && throw(ArgumentError("The hole location doesn't point to a hole!"))

    if cmn isa ConstraintMatchVar
        return nothing, Dict(cmd.rule_ind => rn)
    elseif cmn isa ConstraintMatchNode
        if rn.ind ≠ cmn.rule_ind || length(rn.children) ≠ length(cmn.children)
            return nothing, nothing
        else
            vars = Dict()
            forbidden_domain = nothing
            for (i, rnᵢ, cmnᵢ) ∈ zip(1:length(rn.children), rn.children, cmn.children)
                if i == hole_location[1]
                    # Match with finding domain of hole
                    forbidden_domain, varsᵢ = _match_expr(rnᵢ, cmnᵢ, hole_location[begin+1:end])
                else
                    # Regular match
                    varsᵢ = _match_expr(rnᵢ, cmnᵢ)
                end

                if varsᵢ ≡ nothing
                    # unsuccessful match
                    return nothing, nothing
                end
                # Check if another argument already assigned the same variables
                for (k, v) ∈ varsᵢ
                    if k ∈ keys(vars) && v ≠ vars[k]
                        return nothing, nothing
                    end
                    vars[k] = v
                end
            end
            return forbidden_domain, vars
        end
    end
end

function _match_expr(
    ::Hole, 
    cmn::AbstractConstraintMatchNode, 
    hole_location::Vector{Int}
)::Tuple{Union{Int, Symbol, Nothing}, Union{Dict{Symbol, RuleNode}, Nothing}}
    if hole_location == []
        if cmn isa ConstraintMatchVar
            return cmn.variable_name, Dict()
        elseif cmn isa ConstraintMatchNode && cmn.children == []
            return cmn.rule_ind, Dict()
        end
    end
    return nothing, nothing
end

_match_expr(::Hole, ::AbstractConstraintMatchNode)::Union{Dict{Int, RuleNode}, Nothing} = nothing

function _match_expr(rn::RuleNode, cmn::AbstractConstraintMatchNode)::Union{Dict{Int, RuleNode}, Nothing}
    if cmn isa ConstraintMatchVar
        return cmn.variable_name, Dict()
    elseif cmn isa ConstraintMatchNode
        if rn.ind ≠ cmn.rule_ind || length(rn.children) ≠ length(cmn.children)
            return nothing
        else
            vars = Dict()
            for varsᵢ ∈ map(ab -> _match_expr(g, ab[1], ab[2]), zip(rn.children, cmn.children)) 
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
end


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
function propagate(c::ForbiddenTree, grammar::Grammar, context::GrammarContext, domain::Vector{Int})
    for i ∈ 0:length(context.nodeLocation)
        n = get_node_at_location(context.originalExpr, context.nodeLocation[1:i])
        domain_match, vars = _match_expr(n, c.tree, context.nodeLocation[i+1:end])
        remove_from_domain::Int=0
        if vars ≡ nothing || domain_match ≡ nothing
            continue
        elseif domain_match isa Symbol
            # The matched domain is a variable, so we check if it is assigned
            if domain_match ∈ keys(vars) && vars[forbidden_domain].children == []
                # A terminal rulenode is assigned to the variable, so we retrieve the assigned value
                remove_from_domain = vars[domain_match].ind
            else
                # Variable is not assigned, so it acts as a wildcard.
                return []
            end
        elseif domain_match isa Int
            # The domain match is an actual (terminal) rule
            remove_from_domain = domain_match
        end
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
