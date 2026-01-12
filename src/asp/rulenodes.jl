"""
UTILITIES for RuleNode -> ASP transformations
"""


"""
  rulenode_to_ASP(ruleNode::AbstractRuleNode, grammar::AbstractGrammar, node_index::Int64)

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
function rulenode_to_ASP(ruleNode::AbstractRuleNode, grammar::AbstractGrammar, node_index::Int64)
    output = ""
    output *= _node_to_ASP(ruleNode, grammar, node_index)
    parent_index = node_index
    node_index = node_index + 1
    for (child_ind, child) in enumerate(ruleNode.children)
        output *= "child($(parent_index),$(child_ind),$(node_index)).\n"
        ch_output, node_index = rulenode_to_ASP(child, grammar, node_index)
        output *= ch_output
    end
    return output, node_index
end

"""
  _node_to_ASP(node::RuleNode, grammar::AbstractGrammar, node_index::Int64)

Transforms a [RuleNode] into an ASP representation in the form `node(node_index, rule_id)`.
Used internally to transform an AST rulenode.
"""
function _node_to_ASP(node::RuleNode, grammar::AbstractGrammar, node_index::Int64)
    return "node($(node_index),$(get_rule(node))).\n"
end

"""
  _node_to_ASP(node::Union{UniformHole,DomainRuleNode}, grammar::AbstractGrammar, node_index::Int64)

Transforms a [UniformHole] or [DomainRuleNode] into an ASP representation in the form
`1 { node(node_index, rule_id_1); node(node_index, rule_id_2);...} 1.`.
Used internally to transform an AST rulenode.
"""
function _node_to_ASP(node::Union{UniformHole,DomainRuleNode}, grammar::AbstractGrammar, node_index::Int64)
    options = join(["node($(node_index),$(ind))" for ind in filter(x -> node.domain[x], 1:length(grammar.rules))], ";")
    return "1 { $(options) } 1.\n"
end

"""
  _node_to_ASP(node::StateHole, grammar::AbstractGrammar, node_index::Int64)

Transform a [StateHole] into an ASP representation in the form
`1 { node(node_index, rule_id_1); node(node_index, rule_id_2);...} 1.`
Used internally to transform an AST rulenode.
"""
function _node_to_ASP(node::StateHole, grammar::AbstractGrammar, node_index::Int64)
    options = join(["node($(node_index),$(ind))" for ind in Base.findall(node.domain)], ";")
    return "1 { $(options) } 1.\n"
end

function constraint_rulenode_to_ASP(
    ::AbstractGrammar,
    vn::VarNode,
    node_index::Int,
    ::Int
)
    varnode_equality = enforce_varnode_equality(vn, node_index)

    return "node(X$(node_index),X$(node_index))" * varnode_equality, "", node_index
end

"""
    constraint_rulenode_to_ASP(grammar::AbstractGrammar, ruleNode::AbstractRuleNode, node_index::Int64, constraint_index::Int64)

Transforms a template RuleNode to an ASP form suitable for constraints.

@rulenode 5{3,3} -> node(X1,5),child(X1,1,X2),node(X2,3),child(X1,2,X3),node(X3,3)

@rulenode [4,5]{3,3} -> allowed(x1,1).node(X1,D1),allowed(x1,D1),child(X1,1,X2),node(X2,3),child(X1,2,X3),node(X3,3).
"""
function constraint_rulenode_to_ASP(grammar::AbstractGrammar, ruleNode::AbstractRuleNode, node_index::Int64, constraint_index::Int64)
    tree_facts, additional_facts = "", ""
    tmp_facts, tmp_additional = _constraint_node_to_ASP(grammar, ruleNode, node_index, constraint_index::Int64)
    tree_facts *= "$(tmp_facts)"
    varnode_equality = enforce_varnode_equality(ruleNode, node_index)
    additional_facts *= join(tmp_additional, "")
    parent_index = node_index
    node_index += 1
    for (child_ind, child) in enumerate(ruleNode.children)
        if isa(child, VarNode)
            # Create a variable (uppercase) of the node name, which is a symbol
            node_name = titlecase(string(child.name))
            tree_facts *= ",child(X$parent_index,$child_ind,X$node_index)"
            node_index += 1
        else
            tmp_facts, tmp_additional = _constraint_node_to_ASP(grammar, child, node_index, constraint_index)
            tree_facts *= ",child(X$(parent_index),$(child_ind),X$(node_index))"
            tree_facts *= ",$(tmp_facts)"
            additional_facts *= join(tmp_additional, "")
            node_index += 1
        end
    end
    tree_facts *= varnode_equality
    return tree_facts, additional_facts, node_index
end

"""
    _constraint_node_to_ASP(grammar::AbstractGrammar, node::RuleNode, node_index::Int64, constraint_index::Int64)

Transforms a [RuleNode] into an ASP representation in the form
`node(X_node_index, RuleNode_index).`
Used internally to transform an AST rulenode of a constraint.
"""
function _constraint_node_to_ASP(grammar::AbstractGrammar, node::RuleNode, node_index::Int64, constraint_index::Int64)
    return "node(X$(node_index),$(get_rule(node)))", []
end

"""
    _constraint_node_to_ASP(grammar::AbstractGrammar, node::RuleNodUnion{UniformHole,DomainRuleNode}, node_index::Int64, constrain_index::Int64)

Transforms a [UniformHole] or [DomainRuleNode] into an ASP representation in the form
`node(X_node_index, D_node_index, allowed(c{constraint_index}x{node_index}, D_node_index))`
and the allowed domains of this constraint node.
Used internally to transform an AST rulenode of a constraint.
"""
function _constraint_node_to_ASP(grammar::AbstractGrammar, node::Union{UniformHole,DomainRuleNode}, node_index::Int64, constraint_index::Int64)
    return "node(X$(node_index),D$(node_index)),allowed(c$(constraint_index)x$(node_index),D$(node_index))", map(x -> "allowed(c$(constraint_index)x$(node_index),$x).\n", collect(filter(x -> node.domain[x], 1:length(grammar.rules))))
end

"""
    _constraint_node_to_ASP(grammar::AbstractGrammar, node::StateHole, node_index::Int64, constrain_index::Int64)

Transforms a [StateHole] into an ASP representation in the form
`node(X_node_index, D_node_index, allowed(c{constraint_index}x{node_index}, D_node_index))` 
and the allowed domains of this constraint node.
Used internally to transform an AST rulenode of a constraint.
"""
function _constraint_node_to_ASP(grammar::AbstractGrammar, node::StateHole, node_index::Int64, constraint_index::Int64)
    return "node(X$(node_index),D$(node_index)),allowed(c$(constraint_index)x$(node_index),D$(node_index))", map(x -> "allowed(c$(constraint_index)x$(node_index),$x).\n", Base.findall(node.domain))
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
function map_varnodes_to_asp_indices(
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

function map_varnodes_to_asp_indices(
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
function enforce_varnode_equality(rn::AbstractRuleNode, idx::Int)
    _, varnodes = map_varnodes_to_asp_indices(rn; idx)
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
