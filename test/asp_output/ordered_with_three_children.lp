% Ordered(4{a,b,c}, [:b, :c, :a])
:- node(X1,4),child(X1,1,X2),node(X2,_),child(X1,2,X3),node(X3,_),child(X1,3,X4),node(X4,_),not is_smaller(X3,X4).
:- node(X1,4),child(X1,1,X2),node(X2,_),child(X1,2,X3),node(X3,_),child(X1,3,X4),node(X4,_),not is_smaller(X4,X2).

