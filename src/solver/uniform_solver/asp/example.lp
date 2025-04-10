%% Example trees with grammar
    % g = @csgrammar begin
    %     Number = |(1:2)
    %     Number = x
    %     Number = Number + Number
    %     Number = Number * Number
    % end

%%% Tree 1
    %       1:+/*
    % 2:1/2/x    3:1/2/x
% 1 { node(1,4..5) } 1.
% 1 { node(2,1..3) } 1.
% 1 { node(3,1..3) } 1.
% child(1,1,2).
% child(1,2,3).

%%% Tree 2
    %               4:+/*
    %       5:1/2/x/+/*   6:1/2/x
    % 7:1/2/x         8:1/2/x
1 { node(4,4..5) } 1.
1 { node(5,1..5) } 1.
1 { node(6,1..3) } 1.
1 { node(7,1..3) } 1.
1 { node(8,1..3) } 1.
child(4,1,5).
child(4,2,6).
child(5,1,7).
child(5,2,8).


%%% Example constraints
% Forbid a tree where RuleNode 3 is a child of RuleNode 5
% forbidden(5,3).

% Forbid a tree where RuleNode 3 is the 1st child of RuleNode 5
% forbidden(5,1,3).

% RuleNode 4 must be used
% contains(4).

% Subtree where RuleNode 4 has 1st child RuleNode 2 and as 2nd child RuleNode 3 must be used
% contains(4,1,2).
% contains(4,2,3).

% RuleNode 4: 1st child must have a RuleNode with index smaller or equal to the index of the 2mnd child's RuleNode
% ordered(4,1,2).

% Forbids a tree where a RuleNode 4 has a child somewhere with RuleNode 1 
% forbidden_sequence(4,1).

% :- node(X,5), child(X,1,Y), node(Y,YD), allowed(yD,YD).
% allowed(yD,3).
% allowed(yD,2).
% allowed(yD,1).

% Ordered(5, [y,z], [y, z])
ordered_subtree(X,Y,Z) :- node(X,5), child(X,1,Y), node(Y, YR), child(X,2,Z), node(Z,ZR), YR <= ZR.
% ordered_subtree(YC,ZC) :- ordered_subtree(X,Y,Z), child(Y,Int,YC), node(YC, YR), child(Z,Int,ZC), node(ZC,ZR), YR <= ZR.
invalid :- not ordered_subtree(_,_,_).
:- invalid.

