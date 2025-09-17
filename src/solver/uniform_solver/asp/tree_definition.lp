% Choice vars: n and d are parameters that we can set to control the size of the search space. n is the number of nodes in the tree, and d is the number of derivation rules in the grammar.
#const n = 8. % number of nodes
#const d = 5. % number of derivation rules

node(1..n).

% for each node, select whether to include it and, if yes, which derivation rule to use. We can do this easily by saying that their domain is [ 0 , . . . , d ] where 0 means "not included" and 1 − d are derivation rule indices.

1 { node(X,0..d) } 1 :- node(X).

% for an edge between any pair of nodes, choose whether it exists or not

% X is a parent of Y, maybe also account for the order of children?
0 { child(X,Y) } 1 :- node(X), node(Y).


%%%% Constraints:

% based on the values in the nodes, constrain how many children a node can have

% if a node is not included, it shouldn't have children
:- node(X,0), child(X,_).
% if a node is a terminal, it shouldn't have children
:- node(X,1), child(X,_).
% if a node is a terminal, it shouldn't have children
:- node(X,2), child(X,_).
% if a node is a terminal, it shouldn't have children
:- node(X,3), child(X,_).
% if a node is a plus, it should have exactly two children
:- node(X,4), #count{Y: child(X,Y) } != 2.  

% states which rule indices can appear in the children of a node with type Number
allowed_number_child(1..5).
:- node(X,4), child(X,Y), node(Y,YV), not allowed_number_child(YV). 


% impose valid parent-child relationships: each child must have only one parent,
:- child(X,Y), child(Z,Y), X != Z.

% there must be a root node,
there_is_root :- node(X,Y), Y>0, not child(_,X).
:- not there_is_root.

% no disconnected trees [more difficult, have to think] each included node needs to have a parent or a child
:- node(X,Y), Y > 0, not child(X,_), not child(_,X).

% for symmetry breaking, if node K is not selected, then none of the K + 1 , K + 2 , . . . can be selected.
:- node(X,0), node(Y,Z),Z>0, Y > X.

% then each of our constraints.
%for ORdered, we need to implement an order comparison as in Herb and impose a constraint that "it is impossible that for any node which has a + assigned to it, its children violate ordered"

:- node(X,4), child(X,Y), child(X,Z), Y != Z, not smaller(Y,Z).

% for forbidden constraint, we simple forbid a specific pattern. For instance, if forbid(4{1,1})

:- node(X,4), child(X,Y), node(Y,1), child(X,Z), node(Z,1), Y != Z. 
