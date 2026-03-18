"""
    grammar_to_ASP(grammar::AbstractGrammar)

Transforms each global constraint into ASP format.
"""
function HerbConstraints.grammar_to_ASP(grammar::AbstractGrammar)
    output = ""
    for (const_ind, constraint) in enumerate(grammar.constraints)
        output *= "% $(constraint)\n"
        output *= constraint_to_ASP(grammar, constraint, const_ind)
        output *= "\n"
    end
    return output
end

"""
    constraint_to_ASP(grammar::AbstractGrammar, constraint::Forbidden, constraint_index::Int64)

Transforms the forbidden constraint into ASP format.

```
@rulenode 5{[1,2,3],[1,2,3]} ->

allowed(c1x2,1).
allowed(c1x2,2).
allowed(c1x2,3).
allowed(c1x3,1).
allowed(c1x3,2).
allowed(c1x3,3).
:- node(X1,5), child(X1,1,X2), node(X2,D2), allowed(c1x2,D2), child(X1,2,X3), node(X3,D3), allowed(c1x3,D3).
```
"""
function HerbConstraints.constraint_to_ASP(grammar::AbstractGrammar, constraint::Forbidden, constraint_index::Int64)
    tree_facts, domains, _ = constraint_rulenode_to_ASP(grammar, constraint.tree, 1, constraint_index)
    output = domains
    output *= "subtree(c$(constraint_index)) :- $(tree_facts).\n:- subtree(c$(constraint_index)).\n"
    return output
end

"""
    constraint_to_ASP(::AbstractGrammar, constraint::Contains, constraint_index::Int64)

Transforms the contains constraint into ASP format.

```
Contains(4) -> :- not node(_,4).
```
"""
function HerbConstraints.constraint_to_ASP(::AbstractGrammar, constraint::Contains, constraint_index::Int64)
    return ":- not node(_,$(constraint.rule)).\n"
end

"""
    constraint_to_ASP(::AbstractGrammar, constraint::Unique, constraint_index::Int64)

Transforms the unique constraint into ASP format.

```
Unique(4) -> { node(X,4) : node(X,4) } 1.
```
"""
function HerbConstraints.constraint_to_ASP(::AbstractGrammar, constraint::Unique, constraint_index::Int64)
    return "{ node(X,$(constraint.rule)) : node(X,$(constraint.rule)) } 1.\n"
end

"""
    constraint_to_ASP(grammar::AbstractGrammar, constraint::ContainsSubtree, constraint_index::Int64)

Transforms the contains subtree constraint into ASP format.

```
ContainsSubtree(5{1,2}) ->
subtree(c1) :- node(X1,5), child(X1,1,X2), node(X2,1), child(X1,2,X3), node(X3,2).
:- not subtree(c1).
```
"""
function HerbConstraints.constraint_to_ASP(grammar::AbstractGrammar, constraint::ContainsSubtree, constraint_index::Int64)
    tree, domains, _ = constraint_rulenode_to_ASP(grammar, constraint.tree, 1, constraint_index)
    output = domains
    output *= "subtree(c$(constraint_index)) :- $(tree).\n:- not subtree(c$(constraint_index)).\n"
    return output
end

"""
    constraint_to_ASP(grammar::AbstractGrammar, constraint::Ordered, constraint_index::Int64)

Transforms the Ordered constraint into ASP format. 

# Examples

```jldoctest
g = @csgrammar begin
    Int = 1 | 2 | 3 | 4
    Int = Int + Int
end

julia> println(constraint_to_ASP(g, Ordered(RuleNode(5, [VarNode(:X), VarNode(:Y)]), [:X, :Y]), 1))
is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV < YV.
is_smaller(X,Y) :-
    node(X,XV), node(Y,YV),
    XV = YV, X != Y,
    is_smaller(XC, YC) : child(X,N,XC), child(Y,N,YC). 
:- node(X1,5),child(X1,1,X),child(X1,2,Y), not is_smaller(X,Y).

julia> println(constraint_to_ASP(g, Ordered(RuleNode(5, [VarNode(:X), VarNode(:Y), VarNode(:Z)]), [:X, :Y, :Z]), 1))
is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV < YV.
is_smaller(X,Y) :-
    node(X,XV), node(Y,YV),
    XV = YV, X != Y,
    is_smaller(XC, YC) : child(X,N,XC), child(Y,N,YC). 
:- node(X1,5),child(X1,1,X2),node(X2,X),child(X1,2,X3),node(X3,Y),child(X1,3,X4),node(X4,Z),not is_smaller(X,Y).
:- node(X1,5),child(X1,1,X2),node(X2,X),child(X1,2,X3),node(X3,Y),child(X1,3,X4),node(X4,Z),not is_smaller(Y,Z).
```
"""
function HerbConstraints.constraint_to_ASP(grammar::AbstractGrammar, constraint::Ordered, constraint_index::Int64)
    # X is smaller than Y if the rule index of X is < Y's 
    # X is smaller than Y if their indices are equal but "is_smaller" holds for each of X and Y's children
    output = ""

    tree, domains, _ = constraint_rulenode_to_ASP(grammar, constraint.tree, 1, constraint_index)
    output *= domains

    _, varnode_map = map_varnodes_to_asp_indices(constraint.tree)

    # create ordered constraints, for each consecutive pair of ordered vars
    for (x, y) in zip(constraint.order[1:end-1], constraint.order[2:end])
        @show x,y
        xi = only(varnode_map[x])
        yi = only(varnode_map[y])
        @show xi, yi

        output *= ":- $(tree),not is_smaller(X$(only(varnode_map[x])),X$(only(varnode_map[y]))).\n"
    end

    return output
end

"""
    constraint_to_ASP(::AbstractGrammar, constraint::ForbiddenSequence, constraint_index::Int64)

Transforms the `ForbiddenSequence` constraint into ASP format.

The encoding matches the semantics of `check_tree`:
- the forbidden sequence must occur on one vertical path
- gaps are allowed
- any `ignore_if` rule on the active segment cancels that attempt
- except when the sequence is completed at the current node: then it is already a violation

```jldoctest
julia> println(constraint_to_ASP(g, ForbiddenSequence([1,2,3]), 1))
ignored_c1(X) :- node(X,R), ignore_c1(R).
clean_desc_c1(X,Y) :- child(X,N,Y), not ignored_c1(Y).
clean_desc_c1(X,Z) :- child(X,N,Y), not ignored_c1(Y), clean_desc_c1(Y,Z).
open_desc_c1(X,Y) :- child(X,N,Y).
open_desc_c1(X,Z) :- child(X,N,Y), not ignored_c1(Y), open_desc_c1(Y,Z).
match_c1_1(X) :- node(X,1), not ignored_c1(X).
match_c1_2(Y) :- match_c1_1(X), clean_desc_c1(X,Y), node(Y,2).
bad_c1(Y) :- match_c1_2(X), open_desc_c1(X,Y), node(Y,3).
:- bad_c1(X).
```
"""
function HerbConstraints.constraint_to_ASP(::AbstractGrammar, constraint::ForbiddenSequence, constraint_index::Int64)
    seq = constraint.sequence
    ign = constraint.ignore_if
    cid = "c$(constraint_index)"

    output = ""

    # rules that cancel an in-progress match
    for r in ign
        output *= "ignore_$(cid)($(r)).\n"
    end
    output *= "ignored_$(cid)(X) :- node(X,R), ignore_$(cid)(R).\n"

    # Length-1 sequence: any occurrence is immediately forbidden.
    # This matches `check_tree`, where matching the last element violates
    # before the ignore_if check is reached.
    if length(seq) == 1
        output *= ":- node(X,$(seq[1])).\n"
        return output
    end

    # strict descendant relation where every node on the path, including the end,
    # is not ignored
    output *= "clean_desc_$(cid)(X,Y) :- child(X,N,Y), not ignored_$(cid)(Y).\n"
    output *= "clean_desc_$(cid)(X,Z) :- child(X,N,Y), not ignored_$(cid)(Y), clean_desc_$(cid)(Y,Z).\n"

    # strict descendant relation where all intermediate nodes are not ignored,
    # but the endpoint itself may be ignored
    output *= "open_desc_$(cid)(X,Y) :- child(X,N,Y).\n"
    output *= "open_desc_$(cid)(X,Z) :- child(X,N,Y), not ignored_$(cid)(Y), open_desc_$(cid)(Y,Z).\n"

    # start matching at any node with the first rule, as long as this start node
    # itself is not ignored (for sequences of length > 1)
    output *= "match_$(cid)_1(X) :- node(X,$(seq[1])), not ignored_$(cid)(X).\n"

    # match all intermediate symbols
    for i in 2:length(seq)-1
        output *= "match_$(cid)_$(i)(Y) :- match_$(cid)_$(i-1)(X), clean_desc_$(cid)(X,Y), node(Y,$(seq[i])).\n"
    end

    # complete the forbidden sequence
    output *= "bad_$(cid)(Y) :- match_$(cid)_$(length(seq)-1)(X), open_desc_$(cid)(X,Y), node(Y,$(seq[end])).\n"
    output *= ":- bad_$(cid)(X).\n"

    return output
end

function HerbConstraints.rulenode_comparisons_asp()
    output = """
    is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV < YV.
    is_smaller(X,Y) :-
        node(X,XV), node(Y,YV),
        XV = YV, X != Y,
        is_smaller(XC, YC) : child(X,N,XC), child(Y,N,YC). 

    is_same(X,Y) :-
        node(X,XV), node(Y,YV),
        XV = YV, X != Y,
        is_same(XC, YC) : child(X,N,XC), child(Y, N, YC).
    """

    return output
end

function HerbConstraints.rulenode_comparisons_asp(solver::ASPSolver)
    # No need to include comparisons if there is a single rulenode in the tree 
    if length(get_tree(solver)) == 1
        return ""
    else
        return rulenode_comparisons_asp()
    end
end
