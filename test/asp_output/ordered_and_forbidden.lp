% Ordered(3{a,b}, [:a, :b])
:- node(X1,3),child(X1,1,X2),node(X2,_),child(X1,2,X3),node(X3,_),not is_smaller(X2,X3).

% Forbidden(3{a,a})
subtree(c2) :- node(X1,3),is_same(X2,X3),child(X1,1,X2),node(X2,_),child(X1,2,X3),node(X3,_).
:- subtree(c2).

