"""
UTILITIES for tree -> ASP transformations
"""


"""
  tree_to_ASP(tree::AbstractRuleNode, grammar::AbstractGrammar, node_index::Int64)

Transforms a [UniformTree] into an ASP program.
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
function tree_to_ASP(tree::AbstractRuleNode, grammar::AbstractGrammar, node_index::Int64)
    output = ""
    output *= node_to_ASP(tree, grammar, node_index)
    parent_index = node_index
    node_index = node_index + 1
    for (child_ind, child) in enumerate(tree.children)
        output *= "child($(parent_index),$(child_ind),$(node_index)).\n"
        ch_output, node_index = tree_to_ASP(child, grammar, node_index)
        output *= ch_output
    end
    return output, node_index
end

"""
  node_to_ASP(tree::RuleNode, grammar::AbstractGrammar, node_index::Int64)

Transforms a [RuleNode] into an ASP representation in the form `node(node_index, rule_id)`.
"""
function node_to_ASP(tree::RuleNode, grammar::AbstractGrammar, node_index::Int64)
    return "node($(node_index),$(get_rule(tree))).\n"
end

"""
  node_to_ASP(tree::Union{UniformHole,DomainRuleNode}, grammar::AbstractGrammar, node_index::Int64)

Transforms a [UniformHole] or [DomainRuleNode] into an ASP representation in the form
`1 { node(node_index, rule_id_1); node(node_index, rule_id_2);...} 1.`.
"""
function node_to_ASP(tree::Union{UniformHole,DomainRuleNode}, grammar::AbstractGrammar, node_index::Int64)
    options = join(["node($(node_index),$(ind))" for ind in filter(x -> tree.domain[x], 1:length(grammar.rules))], ";")
    return "1 { $(options) } 1.\n"
end

"""
  node_to_ASP(tree::StateHole, grammar::AbstractGrammar, node_index::Int64)

Transform a [StateHole] into an ASP representation in the form
`1 { node(node_index, rule_id_1); node(node_index, rule_id_2);...} 1.`
"""
function node_to_ASP(tree::StateHole, grammar::AbstractGrammar, node_index::Int64)
    options = join(["node($(node_index),$(ind))" for ind in Base.findall(tree.domain)], ";")
    return "1 { $(options) } 1.\n"
end

"""
    constraint_tree_to_ASP(grammar::AbstractGrammar, tree::AbstractRuleNode, node_index::Int64, constraint_index::Int64)

Transforms a template tree to an ASP form suitable for constraints.

@rulenode 5{3,3} -> node(X1,5),child(X1,1,X2),node(X2,3),child(X1,2,X3),node(X3,3)

@rulenode [4,5]{3,3} -> allowed(x1,1).node(X1,D1),allowed(x1,D1),child(X1,1,X2),node(X2,3),child(X1,2,X3),node(X3,3).
"""
function constraint_tree_to_ASP(grammar::AbstractGrammar, tree::AbstractRuleNode, node_index::Int64, constraint_index::Int64)
    tree_facts, additional_facts = "", ""
    tmp_facts, tmp_additional = constraint_node_to_ASP(grammar, tree, node_index, constraint_index::Int64)
    tree_facts *= "$(tmp_facts)"
    additional_facts *= join(tmp_additional, "")
    parent_index = node_index
    node_index += 1
    for (child_ind, child) in enumerate(tree.children)
        if isa(child, VarNode)
            # Create a variable (uppercase) of the node name, which is a symbol
            node_name = titlecase(string(child.name))
            tree_facts *= ",child(X$(parent_index),$(child_ind),X$(node_index)),node(X$(node_index),$(node_name))"
            node_index += 1
        else
            tmp_facts, tmp_additional = constraint_tree_to_ASP(grammar, child, node_index, constraint_index)
            tree_facts *= ",child(X$(parent_index),$(child_ind),X$(node_index))"
            tree_facts *= ",$(tmp_facts)"
            additional_facts *= join(tmp_additional, "")
            node_index += 1
        end
    end
    return tree_facts, additional_facts, node_index
end

"""
    constraint_node_to_ASP(grammar::AbstractGrammar, node::RuleNode, node_index::Int64, constraint_index::Int64)

Transforms a [RuleNode] into an ASP representation in the form
`node(X_node_index, RuleNode_index).`
"""
function constraint_node_to_ASP(grammar::AbstractGrammar, node::RuleNode, node_index::Int64, constraint_index::Int64)
    return "node(X$(node_index),$(get_rule(node)))", []
end

"""
    constraint_node_to_ASP(grammar::AbstractGrammar, node::VarNode, node_index::Int64, constraint_index::Int64)

Transforms a [VarNode] into an ASP representation in the form
`node(X_node_index, node_name).`

This is only used when a constraint takes the form of just one VarNode, otherwise, VarNodes are already caught in case of the tree children in the `constraint_tree_to_ASP` call.
"""
function constraint_node_to_ASP(grammar::AbstractGrammar, node::VarNode, node_index::Int64, constraint_index::Int64)
    # Create a variable (uppercase) of the node name, which is a symbol
    node_name = titlecase(string(node.name))    
    return "node(X$(node_index),$(node_name))", []
end

"""
    constraint_node_to_ASP(grammar::AbstractGrammar, node::RuleNodUnion{UniformHole,DomainRuleNode}, node_index::Int64, constrain_index::Int64)

Transforms a [UniformHole] or [DomainRuleNode] into an ASP representation in the form
`node(X_node_index, D_node_index, allowed(c{constraint_index}x{node_index}, D_node_index))`
and the allowed domains of this constraint node.
"""
function constraint_node_to_ASP(grammar::AbstractGrammar, node::Union{UniformHole,DomainRuleNode}, node_index::Int64, constraint_index::Int64)
    return "node(X$(node_index),D$(node_index)),allowed(c$(constraint_index)x$(node_index),D$(node_index))", map(x -> "allowed(c$(constraint_index)x$(node_index),$x).\n", collect(filter(x -> node.domain[x], 1:length(grammar.rules))))
end

"""
    constraint_node_to_ASP(grammar::AbstractGrammar, node::StateHole, node_index::Int64, constrain_index::Int64)

Transforms a [StateHole] into an ASP representation in the form
`node(X_node_index, D_node_index, allowed(c{constraint_index}x{node_index}, D_node_index))` 
and the allowed domains of this constraint node.
"""
function constraint_node_to_ASP(grammar::AbstractGrammar, node::StateHole, node_index::Int64, constraint_index::Int64)
    return "node(X$(node_index),D$(node_index)),allowed(c$(constraint_index)x$(node_index),D$(node_index))", map(x -> "allowed(c$(constraint_index)x$(node_index),$x).\n", Base.findall(node.domain))
end
