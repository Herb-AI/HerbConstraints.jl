"""
    grammar_to_ASP(grammar::AbstractGrammar)

Transforms each global constraint into ASP format.
"""
function HerbConstraints.grammar_to_ASP(io::IO, grammar::AbstractGrammar)
    for (const_ind, constraint) in enumerate(grammar.constraints)
        println(io, "% ", constraint)
        constraint_to_ASP(io, constraint, const_ind)
        println(io)
    end
end

function Base.show(io, ::MIME"text/clingo", grammar::AbstractGrammar)
    HerbConstraints.grammar_to_ASP(io, grammar)
    return nothing
end

HerbConstraints.grammar_to_ASP(grammar::AbstractGrammar) = repr(MIME("text/clingo"), grammar)

function Base.show(io, ::MIME"text/clingo", constraint::AbstractConstraint)
    constraint_index = get(io, :constraint_index, 1)
    HerbConstraints.constraint_to_ASP(io, constraint, constraint_index)
    return nothing
end

"""
    HerbConstraints.constraint_to_ASP([io::IO], constraint::Forbidden, constraint_index::Int64)

Encode the [`Forbidden`](@ref) constraint to `ASP`.

Write to `io`, if provided, or return the string, if not.
"""
function HerbConstraints.constraint_to_ASP(constraint::AbstractConstraint, constraint_index::Int)
    return repr(MIME("text/clingo"), constraint; context=:constraint_index => constraint_index)
end

function HerbConstraints.constraint_to_ASP(io::IO, constraint::Forbidden, constraint_index::Int64)
    print(io, "subtree(c", constraint_index, ") :- ")
    constraint_rulenode_to_ASP(io, constraint.tree, 1)
    println(io, ".\n:- subtree(c", constraint_index, ").")
    return nothing
end

function HerbConstraints.constraint_to_ASP(io::IO, constraint::Contains, ::Int64)
    println(io, ":- not node(_,", constraint.rule, ").")
    return nothing
end

function HerbConstraints.constraint_to_ASP(io::IO, constraint::Unique, ::Int64)
    println(io, "{ node(X,", constraint.rule, ") : node(X,", constraint.rule, ") } 1.")
    return nothing
end

function HerbConstraints.constraint_to_ASP(io::IO, constraint::ContainsSubtree, constraint_index::Int64)
    print(io, "subtree(c", constraint_index, ") :- ")
    constraint_rulenode_to_ASP(io, constraint.tree, 1)
    println(io, ".\n:- not subtree(c", constraint_index, ").")
    return nothing
end

function HerbConstraints.constraint_to_ASP(io::IO, constraint::Ordered, ::Int64)
    # X is smaller than Y if the rule index of X is < Y's 
    # X is smaller than Y if their indices are equal but "is_smaller" holds for each of X and Y's children
    _, varnode_map = map_varnodes_to_asp_indices(constraint.tree)

    # create ordered constraints, for each consecutive pair of ordered vars
    for (x, y) in zip(constraint.order[1:end-1], constraint.order[2:end])
        print(io, ":- ")
        constraint_rulenode_to_ASP(io, constraint.tree, 1)
        println(io, ",not is_smaller(X", only(varnode_map[x]), ",X", only(varnode_map[y]), ").")
    end
    return nothing
end

function HerbConstraints.rulenode_comparisons_asp(io::IO)
    println(
        io,
        """
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
    )
    return nothing
end

function HerbConstraints.rulenode_comparisons_asp(io::IO, solver::ASPSolver)
    # No need to include comparisons if there is a single rulenode in the tree 
    if length(get_tree(solver)) == 1
        return ""
    else
        return rulenode_comparisons_asp(io)
    end
end
