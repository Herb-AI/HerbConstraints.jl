"""
    rulenode_to_ASP(rulenode::AbstractRuleNode, grammar::AbstractGrammar, node_index::Int64)

Transforms a [AbstractRuleNode] into an ASP program.
Nodes get their IDs based on the in-order traversal.

Examples:

@rulenode 4{1,2}
->
node(1,4).
child(1,1,2).
node(2,1).
child(1,2,3).
node(3,2).

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
function HerbConstraints.rulenode_to_ASP(rulenode::AbstractRuleNode, grammar::AbstractGrammar, node_index::Int64)
    output = "node($node_index,$(domain_to_asp(rulenode, grammar, node_index))).\n"
    children_output, node_index = rulenode_to_ASP(get_children(rulenode), grammar, node_index)
    output *= children_output
    return output, node_index
end

function HerbConstraints.rulenode_to_ASP(rulenode::Union{UniformHole,DomainRuleNode,StateHole}, grammar::AbstractGrammar, node_index::Int64)
    output = ""
output *= "1 { node($node_index,$(domain_to_asp(rulenode, grammar, node_index))) } 1.\n"
    children_output, node_index = rulenode_to_ASP(get_children(rulenode), grammar, node_index)
    output *= children_output
    return output, node_index
end

function HerbConstraints.rulenode_to_ASP(
    children::AbstractVector{<:AbstractRuleNode},
    grammar::AbstractGrammar,
    node_index::Int
)
    output = ""
    parent_index = node_index

    for (child_ind, child) in enumerate(children)
        output *= "child($(parent_index),$(child_ind),$(node_index+1)).\n"
        ch_output, node_index = rulenode_to_ASP(child, grammar, node_index+1)
        output *= ch_output
    end

    return output, node_index 
end

"""
    domain_to_asp(rulenode::RuleNode, ::AbstractGrammar, node_index::Int64)

Transform the domain of `rulenode` into an ASP representation.

For [`RuleNode`](@ref)s, the domain is a single value.

```jldoctest
julia> g = @csgrammar begin
    Int = Int + Int
    Int = 1
end;

julia> domain_to_asp((@rulenode 1{2,2}), g, 42) 

"node(42, 1)"
```
"""
function domain_to_asp(rulenode::RuleNode, ::AbstractGrammar, ::Int)
    return "$(get_rule(rulenode))"
end

function domain_to_asp(rulenode::Union{UniformHole,DomainRuleNode,StateHole}, ::AbstractGrammar, ::Int)
    return "(" * join(sort(findall(rulenode.domain)), ";") * ")"
end

function HerbConstraints.constraint_rulenode_to_ASP(
    ::AbstractGrammar,
    vn::VarNode,
    node_index::Int,
    constraint_index::Int
)
    return "node(X$(node_index),_)", node_index, constraint_index
end

"""
    constraint_rulenode_to_ASP(grammar::AbstractGrammar, rulenode::AbstractRuleNode, node_index::Int64, constraint_index::Int64)

Transforms a template [`RuleNode`](@ref) to an ASP form suitable for constraints.

```
@rulenode 5{3,3} -> node(X1,5),child(X1,1,X2),node(X2,3),child(X1,2,X3),node(X3,3)

@rulenode [4,5]{3,3} -> allowed(x1,1).node(X1,D1),allowed(x1,D1),child(X1,1,X2),node(X2,3),child(X1,2,X3),node(X3,3).
```
"""
function HerbConstraints.constraint_rulenode_to_ASP(grammar::AbstractGrammar, rulenode::AbstractRuleNode, node_index::Int, constraint_index::Int)
    tree_facts = "node(X$node_index,$(domain_to_asp(rulenode, grammar, node_index)))"
    varnode_equality = enforce_varnode_equality(rulenode, node_index)
    children_output, node_index, constraint_index = constraint_rulenode_to_ASP(grammar, get_children(rulenode), node_index, constraint_index)

    tree_facts *= children_output
    tree_facts *= varnode_equality

    return tree_facts, node_index, constraint_index
end

function HerbConstraints.constraint_rulenode_to_ASP(
    grammar::AbstractGrammar,
    children::AbstractVector{<:AbstractRuleNode},
    node_index::Int,
    constraint_index::Int
)
    output = ""
    parent_index = node_index
    for (child_ind, child) in enumerate(children)
        output *= ",child(X$(parent_index),$(child_ind),X$(node_index + 1)),"
        ch_output, node_index, constraint_index = constraint_rulenode_to_ASP(grammar, child, node_index + 1, constraint_index)
        output *= ch_output
    end

    return output, node_index, constraint_index
end

# """
#     constraint_node_to_ASP(grammar::AbstractGrammar, rulenode::RuleNode, node_index::Int, constraint_index::Int)
#
# Transforms a [RuleNode] into an ASP representation in the form
# `node(X_node_index, RuleNode_index).`
#
# """
# function HerbConstraints.constraint_rulenode_to_ASP(grammar::AbstractGrammar, rulenode::RuleNode, node_index::Int, constraint_index::Int)
#     tree_facts = domain_to_asp(rulenode, grammar, node_index)
#     children_output, node_index, constraint_index = constraint_rulenode_to_ASP(grammar, get_children(rulenode), node_index, constraint_index)
#     tree_facts *= children_output
#
#     return tree_facts, node_index, constraint_index
# end

"""
    _constraint_node_to_ASP(grammar::AbstractGrammar, rulenode::Union{UniformHole,DomainRuleNode}, node_index::Int64, constraint_index::Int64)
"""
function HerbConstraints.constraint_rulenode_to_ASP(grammar::AbstractGrammar, rulenode::Union{UniformHole,DomainRuleNode,StateHole}, node_index::Int64, constraint_index::Int64)
    tree_facts = "node(X$node_index,$(domain_to_asp(rulenode, grammar, node_index)))"
    varnode_equality = enforce_varnode_equality(rulenode, node_index)
    children_output, node_index, constraint_index = constraint_rulenode_to_ASP(grammar, get_children(rulenode), node_index, constraint_index)
    tree_facts *= children_output
    tree_facts *= varnode_equality

    return tree_facts, node_index, constraint_index
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
