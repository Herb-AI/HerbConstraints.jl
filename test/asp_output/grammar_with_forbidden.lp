% Forbidden(3{a,b})
subtree(c1) :- node(X1,3),child(X1,1,X2),node(X2,_),child(X1,2,X3),node(X3,_).
:- subtree(c1).

% Forbidden(4{a,b})
subtree(c2) :- node(X1,4),child(X1,1,X2),node(X2,_),child(X1,2,X3),node(X3,_).
:- subtree(c2).

