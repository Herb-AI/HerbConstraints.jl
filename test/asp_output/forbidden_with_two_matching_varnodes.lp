% Forbidden(3{a,a})
subtree(c1) :- node(X1,3),child(X1,1,X2),node(X2,_),child(X1,2,X3),node(X3,_),is_same(X2,X3).
:- subtree(c1).

