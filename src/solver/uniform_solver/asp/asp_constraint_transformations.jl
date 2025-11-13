"""
   to_ASP(grammar::AbstractGrammar)

Transforms each global constraint into ASP format.
"""
function to_ASP(grammar::AbstractGrammar)
    output = ""
    for (const_ind, constraint) in enumerate(grammar.constraints)
        output *= "% $(constraint)\n"
        output *= to_ASP(grammar, constraint, const_ind)
        output *= "\n"
    end
    return output
end

"""
   to_ASP(grammar::AbstractGrammar, constraint::Forbidden, constraint_index::Int64)

Transforms the forbidden constraint into ASP format.

@rulenode 5{[1,2,3],[1,2,3]} ->

allowed(c1x2,1).
allowed(c1x2,2).
allowed(c1x2,3).
allowed(c1x3,1).
allowed(c1x3,2).
allowed(c1x3,3).
:- node(X1,5), child(X1,1,X2), node(X2,D2), allowed(c1x2,D2), child(X1,2,X3), node(X3,D3), allowed(c1x3,D3).
"""
function to_ASP(grammar::AbstractGrammar, constraint::Forbidden, constraint_index::Int64)
    tree_facts, domains, _ = constraint_tree_to_ASP(grammar, constraint.tree, 1, constraint_index)
    output = domains
    output *= "subtree(c$(constraint_index)) :- $(tree_facts).\n:- subtree(c$(constraint_index)).\n"
    return output
end

"""
    to_ASP(grammar::AbstractGrammar, constraint::Contains, constraint_index::Int64)

Transforms the contains constraint into ASP format.

Contains(4) -> :- not node(_,4).
"""
function to_ASP(grammar::AbstractGrammar, constraint::Contains, constraint_index::Int64)
    return ":- not node(_,$(constraint.rule)).\n"
end

"""
    to_ASP(grammar::AbstractGrammar, constraint::Unique, constraint_index::Int64)

Transforms the unique constraint into ASP format.

Unique(4) -> { node(X,4) : node(X,4) } 1.
"""
function to_ASP(grammar::AbstractGrammar, constraint::Unique, constraint_index::Int64)
    return "{ node(X,$(constraint.rule)) : node(X,$(constraint.rule)) } 1.\n"
end

"""
    to_ASP(grammar::AbstractGrammar, constraint::ContainsSubtree, constraint_index::Int64)

Transforms the contains subtree constraint into ASP format.

ContainsSubtree(5{1,2}) ->
subtree(c1) :- node(X1,5), child(X1,1,X2), node(X2,1), child(X1,2,X3), node(X3,2).
:- not subtree(c1).
"""
function to_ASP(grammar::AbstractGrammar, constraint::ContainsSubtree, constraint_index::Int64)
    tree, domains, _ = constraint_tree_to_ASP(grammar, constraint.tree, 1, constraint_index)
    output = domains
    output *= "subtree(c$(constraint_index)) :- $(tree).\n:- not subtree(c$(constraint_index)).\n"
    return output
end

"""
    to_ASP(grammar::AbstractGrammar, constraint::Ordered, constraint_index::Int64)

Transforms the Ordered constraint into ASP format. 

Ordered(5{NodeVar(:X),NodeVar(:Y)}, [:X, :Y]) ->
is_smaller(OrderedXV,OrderedYV) :- node(OrderedX,OrderedXV), node(OrderedY,OrderedYV), OrderedXV < OrderedYV.
is_smaller(OrderedXV,OrderedYV) :- node(OrderedX,OrderedXV), node(OrderedY,OrderedYV), OrderedXV = OrderedYV, OrderedS = #sum {OrderedZ: child(OrderedX,OrderedZ,OrderedXC), child(OrderedY,OrderedZ,OrderedYC), is_smaller(OrderedXC, OrderedYC)}, OrderedM = #max {OrderedZ: child(OrderedX,OrderedZ,OrderedXC)}, OrderedS = OrderedM.
:- node(X1,5),child(X1,1,X),child(X1,2,Y), not is_smaller(X,Y).

Ordered(5{NodeVar(:X),NodeVar(:Y),NodeVar(:Z)}, [:X, :Y, :Z]) ->
is_smaller(OrderedXV,OrderedYV) :- node(OrderedX,OrderedXV), node(OrderedY,OrderedYV), OrderedXV < OrderedYV.
is_smaller(OrderedXV,OrderedYV) :- node(OrderedX,OrderedXV), node(OrderedY,OrderedYV), OrderedXV = OrderedYV, OrderedS = #sum {OrderedZ: child(OrderedX,OrderedZ,OrderedXC), child(OrderedY,OrderedZ,OrderedYC), is_smaller(OrderedXC, OrderedYC)}, OrderedM = #max {OrderedZ: child(OrderedX,OrderedZ,OrderedXC)}, OrderedS = OrderedM.
:- node(X1,5),child(X1,1,X),child(X1,2,Y),child(X1,3,Z) not is_smaller(X,Y).
:- node(X1,5),child(X1,1,X),child(X1,2,Y),child(X1,3,Z) not is_smaller(Y,Z).
"""
function to_ASP(grammar::AbstractGrammar, constraint::Ordered, constraint_index::Int64)
    # Use Ordered{Var} in the is_smaller construct, to prevent same naming as other constraint VarNodes.
    # Use the Values in the head, because the VarNodes are converted to: child(Parent,Index,Node), node(Node,VarNodeName)
    output = "is_smaller(OrderedXV,OrderedYV) :- node(OrderedX,OrderedXV),node(OrderedY,OrderedYV),OrderedXV < OrderedYV.\n"
    output *= "is_smaller(OrderedXV,OrderedYV) :- node(OrderedX,OrderedXV),node(OrderedY,OrderedYV),OrderedXV = OrderedYV,OrderedS = #sum { OrderedZ : child(OrderedX,OrderedZ,OrderedXC),child(OrderedY,OrderedZ,OrderedYC),is_smaller(OrderedXC,OrderedYC) },OrderedM = #max { OrderedZ : child(OrderedX,OrderedZ,OrderedXC) },OrderedS = OrderedM.\n"

    tree, domains, _ = constraint_tree_to_ASP(grammar, constraint.tree, 1, constraint_index)
    output *= domains

    # create ordered constraints, for each consecutive pair of ordered vars
    for i in 1:length(constraint.order)-1
        node_name1 = titlecase(string(constraint.order[i]))
        node_name2 = titlecase(string(constraint.order[i+1]))
        output *= ":- $(tree),not is_smaller($(node_name1),$(node_name2)).\n"
    end

    return output
end
