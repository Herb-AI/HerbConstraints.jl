"""
    rulenode_to_ASP(rulenode::AbstractRuleNode, node_index::Int64)

Transform an [`AbstractRuleNode`](@ref) into an ASP program.

Nodes get their IDs based on the in-order traversal.

## Examples

```jldoctest
julia> rulenode_to_ASP(@rulenode 4{1,2})
node(1,4).
child(1,1,2).
node(2,1).
child(1,2,3).
node(3,2).
```

@rulenode [4,5]{1,2} ->
1 { node(1,4);node(1,5) } 1.
child(1,1,2).
node(2,1).
child(1,2,3).
node(3,2).

@rulenode [4,5]{[1,2,3],[1,2,3]} ->
1 { node(1,4);node(1,5) } 1.
child(1,1,2).
1 { node(2,1);node(2,2);node(2,3) } 1.
child(1,2,3).
1 { node(3,1);node(3,2);node(3,3) } 1.
"""
function HerbConstraints.rulenode_to_ASP(rulenode::AbstractRuleNode, node_index::Int64; is_constraint=false)
    output = if is_constraint
        "node(X$node_index,$(domain_to_asp(rulenode)))" * enforce_varnode_equality(rulenode, node_index)
    else
        "1 { node($node_index,$(domain_to_asp(rulenode))) } 1.\n"
    end
    node_index += 1
    children_output, node_index = rulenode_to_ASP(get_children(rulenode), node_index; is_constraint)
    output *= children_output
    return output, node_index
end

function HerbConstraints.rulenode_to_ASP(
    children::AbstractVector{<:AbstractRuleNode},
    node_index::Int;
    is_constraint=false
)
    output = ""
    parent_index = node_index - 1

    for (child_ind, child) in enumerate(children)
        output *= if is_constraint
            ",child(X$(parent_index),$(child_ind),X$(node_index)),"
        else
            "child($(parent_index),$(child_ind),$(node_index)).\n"
        end
        ch_output, node_index = rulenode_to_ASP(child, node_index; is_constraint)
        output *= ch_output
    end

    return output, node_index
end

"""
    domain_to_asp(rulenode::AbstractRuleNode)

Transform the domain of `rulenode` into an ASP representation.

For [`RuleNode`](@ref)s, the domain is a single value.

For [`VarNode`](@ref)s, the domain is simply `"_"`.

```jldoctest
julia> domain_to_asp((@rulenode 1{2,2}), 42) 

"node(42, 1)"
```
"""
function domain_to_asp(rulenode::RuleNode)
    return "$(get_rule(rulenode))"
end

function domain_to_asp(rulenode::Union{UniformHole,DomainRuleNode,StateHole})
    return "(" * join(sort(findall(rulenode.domain)), ";") * ")"
end

function domain_to_asp(::VarNode)
    return "_"
end

"""
    constraint_rulenode_to_ASP(rulenode::AbstractRuleNode, node_index::Int64, constraint_index::Int64)

Transforms a template [`RuleNode`](@ref) to an ASP form suitable for constraints.

```
@rulenode 5{3,3} -> node(X1,5),child(X1,1,X2),node(X2,3),child(X1,2,X3),node(X3,3)

@rulenode [4,5]{3,3} -> allowed(x1,1).node(X1,D1),allowed(x1,D1),child(X1,1,X2),node(X2,3),child(X1,2,X3),node(X3,3).
```
"""
function HerbConstraints.constraint_rulenode_to_ASP(rulenode::AbstractRuleNode, node_index::Int)
    return rulenode_to_ASP(rulenode, node_index; is_constraint=true)
end

"""
    map_varnodes_to_asp_indices(
        rn::AbstractRuleNode;
        idx=1,
        map=Dict{Symbol,Set{Int}}()
    )::Tuple{Int,Dict{Symbol,Int}}

Construct a mapping between [`VarNode`](@ref)s in `rn` and their index in ASP
representation.

Return an `(index, map)` tuple where `idx` is the largest index assigned in the
tree. The ASP index of a node in a tree is assigned with a depth-first
traversal.
"""
function HerbConstraints.map_varnodes_to_asp_indices(
    rn::AbstractRuleNode;
    idx=1,
    map=Dict{Symbol,Vector{Int}}()
)::Tuple{Int,Dict{Symbol,Vector{Int}}}
    for c in get_children(rn)
        idx += 1
        idx, map = map_varnodes_to_asp_indices(c; idx, map)
    end

    return idx, map
end

function HerbConstraints.map_varnodes_to_asp_indices(
    vn::VarNode;
    idx=1,
    map=Dict{Symbol,Vector{Int}}()
)::Tuple{Int,Dict{Symbol,Vector{Int}}}
    existing_indices = get!(map, vn.name, Int[])
    push!(existing_indices, idx)

    return idx, map
end

"""
    enforce_varnode_equality(rn::AbstractRuleNode, idx::Int)

If there are multiple [`VarNode`](@ref)s with the same symbol in `rn`, add
`is_same(X,Y)` for ASP representation.
"""
function HerbConstraints.enforce_varnode_equality(rn::AbstractRuleNode, idx::Int)
    _, varnodes = HerbConstraints.map_varnodes_to_asp_indices(rn; idx)
    output = ""

    for (_, indices) in varnodes
        if length(indices) > 1
            for (i1, i2) in zip(indices[1:end-1], indices[2:end])
                output *= ",is_same(X$i1,X$i2)"
            end
        end
    end

    return output
end
