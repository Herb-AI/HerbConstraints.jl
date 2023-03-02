"""
Forbids the subtree to be generated.
Doesn't support variables yet.
"""
struct ForbiddenTree <: PropagatorConstraint
	tree::RuleNode
end

"""
Tries to match rulenodes n₁ and n₂. 
Node n₂ can have its variables filled in.
Returns if match is successful:
    - A dictionary with variable assignments
    - The id for the node which fills the hole
A variable is represented by the index of its rulenode.
Returns nothing if the match is unsuccessful.
"""
function _match_expr(
    g::Grammar, 
    n₁::RuleNode, 
    n₂::RuleNode, 
    hole_location::Vector{Int}
)::Tuple{Union{Int, Nothing}, Union{Dict{Int, RuleNode}, Nothing}}
    # TODO: Simplify this when holes are defined with placeholders.
    if hole_location == []
        return n₂.ind, Dict()
    end
    if length(hole_location) == 1 && n₁.ind == n₂.ind
        forbidden_domain = n₂.children[hole_location[1]]
        vars = _match_expr(g, n₁, n₂)
        if vars ≡ nothing
            return nothing, nothing
        else
            return forbidden_domain, vars
        end
    end

    if Grammars.isvariable(g, n₂)
        return nothing, Dict(n₂.ind => n₁)
    elseif n₁.ind ≠ n₂.ind || length(n₁.children) ≠ length(n₂.children)
        return nothing, nothing
    else
        vars = Dict()
        forbidden_domain = nothing
        for (i, c₁, c₂) ∈ zip(1:length(n₁.children), n₁.children, n₂.children)
            if i == hole_location[1]
                forbidden_domain, varsᵢ = _match_expr(g, c₁, c₂, hole_location[begin+1:end])
            else
                varsᵢ = _match_expr(g, c₁, c₂)
            end
            if varsᵢ ≡ nothing
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


function _match_expr(
    g::Grammar, 
    n₁::RuleNode, 
    n₂::RuleNode
)::Union{Dict{Int, RuleNode}, Nothing}
    if Grammars.isvariable(g, n₂)
        if hole_location == []
            return (domain, Dict(n₂.ind => n₁))
        end
        return nothing, Dict(n₂.ind => n₁)
    elseif n₁.ind ≠ n₂.ind || length(n₁.children) ≠ length(n₂.children)
        return nothing
    else
        vars = Dict()
        for varsᵢ ∈ map(ab -> _match_expr(g, ab[1], ab[2]), zip(n₁.children, n₂.children)) 
            if varsᵢ ≡ nothing 
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


function get_node_at_location(root::RuleNode, location::Vector{Int})
    if location == []
        return root
    else
        return get_node_at_location(root.children[location[1]], location[2:end])
    end
end


"""
Propagates the Forbidden constraint.
It removes the elements from the domain that would complete the forbidden sequence.
"""
function propagate(c::ForbiddenTree, context::GrammarContext, domain::Vector{Int})
    @show context.nodeLocation
    for i ∈ 0:length(context.nodeLocation)
        @show i
        n = get_node_at_location(context.originalExpr, context.nodeLocation[1:i])
        println("Matching $n with $(c.tree) using $(context.nodeLocation[i+1:end])")
        forbidden_domain, vars = _match_expr(context.grammar, n, c.tree, context.nodeLocation[i+1:end])
        @show forbidden_domain, vars
        if vars ≡ nothing || forbidden_domain ≡ nothing
            continue
        elseif Grammars.isvariable(context.grammar, forbidden_domain)
            @show forbidden_domain
            # Check if variable is assigned
            if forbidden_domain ∈ keys(vars)
                # Variable is assigned, so we change the forbidden domain to the assigned value
                forbidden_domain = vars[forbidden_domain]
            else
                # Variable is not assigned, so it acts as a wildcard.
                return []
            end
        end
        @show domain
        loc = findfirst(isequal(forbidden_domain), domain)
        if !(loc ≡ nothing)
            println("PRUNING $loc")
            deleteat!(domain, findfirst(isequal(forbidden_domain), domain))
        end
        if domain == []
            return []
        end
    end
    return domain
end
