subtree(Parent,Int,Child) :- node(NP,Parent), node(NC,Child), child(NP,Int,NC).

offspring(Parent,Offspring) :- subtree(Parent,_,Offspring).
offspring(Parent,Offspring) :- subtree(Parent,_,Child), offspring(Child,Offspring).

%%% Constraints %%%

% Forbidden constraint
:- forbidden(Parent,Child), subtree(Parent,_,Child).
:- forbidden(Parent,Int,Child), subtree(Parent,Int,Child).

% Contains constraint
:- contains(Rule), not node(_,Rule).

% Contains subtree constraint
:- contains(Parent,Int,Child), not subtree(Parent,Int,Child).

% Ordered constraint
:- ordered(Parent,CIndex1,CIndex2), subtree(Parent,CIndex1,Child1), subtree(Parent,CIndex2,Child2), Child1 > Child2.

% Forbidden sequence constraint
:- forbidden_sequence(Parent,OffSpring), offspring(Parent,Offspring).
