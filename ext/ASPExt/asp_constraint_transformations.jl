"""
    grammar_to_ASP(grammar::AbstractGrammar)

Transforms each global constraint into ASP format.
"""
function HerbConstraints.grammar_to_ASP(grammar::AbstractGrammar)
    output = ""
    for (const_ind, constraint) in enumerate(grammar.constraints)
        output *= "% $(constraint)\n"
        output *= constraint_to_ASP(grammar, constraint, const_ind)
        output *= "\n"
    end
    return output
end

"""
    constraint_to_ASP(grammar::AbstractGrammar, constraint::Forbidden, constraint_index::Int64)

Transforms the forbidden constraint into ASP format.

```
@rulenode 5{[1,2,3],[1,2,3]} ->

allowed(c1x2,1).
allowed(c1x2,2).
allowed(c1x2,3).
allowed(c1x3,1).
allowed(c1x3,2).
allowed(c1x3,3).
:- node(X1,5), child(X1,1,X2), node(X2,D2), allowed(c1x2,D2), child(X1,2,X3), node(X3,D3), allowed(c1x3,D3).
```
"""
function HerbConstraints.constraint_to_ASP(grammar::AbstractGrammar, constraint::Forbidden, constraint_index::Int64)
    tree_facts, domains, _ = constraint_rulenode_to_ASP(grammar, constraint.tree, 1, constraint_index)
    output = domains
    output *= "subtree(c$(constraint_index)) :- $(tree_facts).\n:- subtree(c$(constraint_index)).\n"
    return output
end

function _combination_constraint_node_to_ASP(::AbstractGrammar, rulenode::RuleNode, node_index::Int64, label::String)
    return "node(X$(node_index),$(get_rule(rulenode)))", String[]
end

function _combination_constraint_node_to_ASP(grammar::AbstractGrammar, rulenode::DomainRuleNode, node_index::Int64, label::String)
    return "node(X$(node_index),D$(node_index)),allowed($(label)x$(node_index),D$(node_index))",
    ["allowed($(label)x$(node_index),$x).\n" for x in filter(i -> rulenode.domain[i], 1:length(grammar.rules))]
end

function _combination_constraint_rulenode_to_ASP(
    grammar::AbstractGrammar,
    rulenode::AbstractRuleNode,
    node_index::Int64,
    label::String,
)
    if rulenode isa VarNode
        varnode_equality = enforce_varnode_equality(rulenode, node_index)
        return "node(X$(node_index),X$(node_index))" * varnode_equality, "", node_index
    end

    tree_facts, additional_facts = "", ""
    tmp_facts, tmp_additional = _combination_constraint_node_to_ASP(grammar, rulenode, node_index, label)
    tree_facts *= tmp_facts
    additional_facts *= join(tmp_additional, "")
    varnode_equality = enforce_varnode_equality(rulenode, node_index)
    parent_index = node_index
    node_index += 1

    for (child_ind, child) in enumerate(get_children(rulenode))
        if child isa VarNode
            tree_facts *= ",child(X$(parent_index),$(child_ind),X$(node_index))"
            node_index += 1
        else
            tmp_facts, tmp_additional = _combination_constraint_node_to_ASP(grammar, child, node_index, label)
            tree_facts *= ",child(X$(parent_index),$(child_ind),X$(node_index))"
            tree_facts *= ",$(tmp_facts)"
            additional_facts *= join(tmp_additional, "")
            node_index += 1
        end
    end

    tree_facts *= varnode_equality
    return tree_facts, additional_facts, node_index
end

function HerbConstraints.constraint_to_ASP(grammar::AbstractGrammar, constraint::ForbiddenCombination, constraint_index::Int64)
    output = ""
    for (option_index, children) in enumerate(constraint.children)
        pattern = HerbConstraints._forbidden_combination_pattern(constraint.root, children)
        label = "c$(constraint_index)o$(option_index)"
        tree_facts, domains, _ = _combination_constraint_rulenode_to_ASP(grammar, pattern, 1, label)
        output *= domains
        output *= "subtree($(label)) :- $(tree_facts).\n:- subtree($(label)).\n"
    end
    return output
end

"""
    constraint_to_ASP(::AbstractGrammar, constraint::Contains, constraint_index::Int64)

Transforms the contains constraint into ASP format.

```
Contains(4) -> :- not node(_,4).
```
"""
function HerbConstraints.constraint_to_ASP(::AbstractGrammar, constraint::Contains, constraint_index::Int64)
    return ":- not node(_,$(constraint.rule)).\n"
end

"""
    constraint_to_ASP(::AbstractGrammar, constraint::Unique, constraint_index::Int64)

Transforms the unique constraint into ASP format.

```
Unique(4) -> { node(X,4) : node(X,4) } 1.
```
"""
function HerbConstraints.constraint_to_ASP(::AbstractGrammar, constraint::Unique, constraint_index::Int64)
    return "{ node(X,$(constraint.rule)) : node(X,$(constraint.rule)) } 1.\n"
end

"""
    constraint_to_ASP(grammar::AbstractGrammar, constraint::ContainsSubtree, constraint_index::Int64)

Transforms the contains subtree constraint into ASP format.

```
ContainsSubtree(5{1,2}) ->
subtree(c1) :- node(X1,5), child(X1,1,X2), node(X2,1), child(X1,2,X3), node(X3,2).
:- not subtree(c1).
```
"""
function HerbConstraints.constraint_to_ASP(grammar::AbstractGrammar, constraint::ContainsSubtree, constraint_index::Int64)
    tree, domains, _ = constraint_rulenode_to_ASP(grammar, constraint.tree, 1, constraint_index)
    output = domains
    output *= "subtree(c$(constraint_index)) :- $(tree).\n:- not subtree(c$(constraint_index)).\n"
    return output
end

"""
    constraint_to_ASP(grammar::AbstractGrammar, constraint::Ordered, constraint_index::Int64)

Transforms the Ordered constraint into ASP format. 

# Examples

```jldoctest
g = @csgrammar begin
    Int = 1 | 2 | 3 | 4
    Int = Int + Int
end

julia> println(constraint_to_ASP(g, Ordered(RuleNode(5, [VarNode(:X), VarNode(:Y)]), [:X, :Y]), 1))
is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV < YV.
is_smaller(X,Y) :-
    node(X,XV), node(Y,YV),
    XV = YV, X != Y,
    is_smaller(XC, YC) : child(X,N,XC), child(Y,N,YC). 
:- node(X1,5),child(X1,1,X),child(X1,2,Y), not is_smaller(X,Y).

julia> println(constraint_to_ASP(g, Ordered(RuleNode(5, [VarNode(:X), VarNode(:Y), VarNode(:Z)]), [:X, :Y, :Z]), 1))
is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV < YV.
is_smaller(X,Y) :-
    node(X,XV), node(Y,YV),
    XV = YV, X != Y,
    is_smaller(XC, YC) : child(X,N,XC), child(Y,N,YC). 
:- node(X1,5),child(X1,1,X2),node(X2,X),child(X1,2,X3),node(X3,Y),child(X1,3,X4),node(X4,Z),not is_smaller(X,Y).
:- node(X1,5),child(X1,1,X2),node(X2,X),child(X1,2,X3),node(X3,Y),child(X1,3,X4),node(X4,Z),not is_smaller(Y,Z).
```
"""
function HerbConstraints.constraint_to_ASP(grammar::AbstractGrammar, constraint::Ordered, constraint_index::Int64)
    # X is smaller than Y if the rule index of X is < Y's 
    # X is smaller than Y if their indices are equal but "is_smaller" holds for each of X and Y's children
    output = ""

    tree, domains, _ = constraint_rulenode_to_ASP(grammar, constraint.tree, 1, constraint_index)
    output *= domains

    _, varnode_map = map_varnodes_to_asp_indices(constraint.tree)

    # create ordered constraints, for each consecutive pair of ordered vars
    for (x, y) in zip(constraint.order[1:end-1], constraint.order[2:end])
        output *= ":- $(tree),not is_smaller(X$(only(varnode_map[x])),X$(only(varnode_map[y]))).\n"
    end

    return output
end

function HerbConstraints.rulenode_comparisons_asp()
    output = """
    is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV < YV.
    is_smaller(X,Y) :-
        node(X,XV), node(Y,YV),
        XV = YV, X != Y,
        is_smaller(XC, YC) : child(X,N,XC), child(Y,N,YC). 

    is_same(X,Y) :-
        node(X,XV), node(Y,YV),
        XV = YV, X != Y,
        is_same(XC, YC) : child(X,N,XC), child(Y, N, YC).
    """

    return output
end

function HerbConstraints.rulenode_comparisons_asp(solver::ASPSolver)
    # No need to include comparisons if there is a single rulenode in the tree 
    if length(get_tree(solver)) == 1
        return ""
    else
        return rulenode_comparisons_asp()
    end
end
