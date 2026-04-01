subtree(c1) :- node(X1,4),child(X1,1,X2),node(X2,(1;2)),child(X1,2,X3),node(X3,3).
:- not subtree(c1).
