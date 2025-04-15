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

    output *= ":- $(tree_facts).\n"
    return output
end

"""
    to_ASP(grammar::AbstractGrammar, constraint::Contains, index::Int64)

Transforms the contains constraint into ASP format.

Contains(4) -> :- not node(_,4).
"""
function to_ASP(grammar::AbstractGrammar, constraint::Contains, index::Int64)
    return ":- not node(_, $(constraint.rule)).\n"
end

"""
    to_ASP(grammar::AbstractGrammar, constraint::Unique, index::Int64)

Transforms the unique constraint into ASP format.

Unique(4) -> { X : node(X,4) } 1.
"""
function to_ASP(grammar::AbstractGrammar, constraint::Unique, index::Int64)
    return "{ X : node(X, $(constraint.rule)) } 1.\n"
end

"""
    to_ASP(grammar::AbstractGrammar, constraint::ContainsSubtree, index::Int64)

Transforms the contains subtree constraint into ASP format.

ContainsSubtree(5{1,2}) ->
subtree(c1) :- node(X1,5), child(X1,1,X2), node(X2,1), child(X1,2,X3), node(X3,2).
:- not subtree(c1).
"""
function to_ASP(grammar::AbstractGrammar, constraint::ContainsSubtree, index::Int64)
    tree, domains, _ = constraint_tree_to_ASP(grammar, constraint.tree, 1, index)
    output = ""
    output *= domains

    output *= "subtree(c$(index)) :- $(tree).\n:- not subtree(c$(index)).\n"

    return output
end

"""
    to_ASP(grammar::AbstractGrammar, constraint::Ordered, index::Int64)

Transforms the Ordered constraint into ASP format.

Ordered(5{NodeVar(:X),NodeVar(:Y)}, [:X, :Y]) ->
is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV < YV.
is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV = YV, S = #sum {Z: child(X,Z,XC), child(Y,Z,YC), is_smaller(XC, YC)}, M = #max {Z: child(X,Z,XC)}, S = M.
:- node(X1,5),child(X1,1,X),child(X1,2,Y), not is_smaller(X,Y).

Ordered(5{NodeVar(:X),NodeVar(:Y),NodeVar(:Z)}, [:X, :Y, :Z]) ->
is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV < YV.
is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV = YV, S = #sum {Z: child(X,Z,XC), child(Y,Z,YC), is_smaller(XC, YC)}, M = #max {Z: child(X,Z,XC)}, S = M.
:- node(X1,5),child(X1,1,X),child(X1,2,Y),child(X1,3,Z) not is_smaller(X,Y).
:- node(X1,5),child(X1,1,X),child(X1,2,Y),child(X1,3,Z) not is_smaller(Y,Z).
"""
function to_ASP(grammar::AbstractGrammar, constraint::Ordered, index::Int64)
    output = "is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV < YV.\n"
    output *= "is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV = YV, S = #sum {Z: child(X,Z,XC), child(Y,Z,YC), is_smaller(XC, YC)}, M = #max {Z: child(X,Z,XC)}, S = M.\n"

    tree, domains, _ = constraint_tree_to_ASP(grammar, constraint.tree, 1, index)

    output *= domains

    # create ordered constraints, for each consecutive pair of ordered vars
    for i in 1:length(constraint.order)-1
        output *= ":- $(tree), not is_smaller($(constraint.order[i]), $(constraint.order[i+1])).\n"
    end

    return output
end
