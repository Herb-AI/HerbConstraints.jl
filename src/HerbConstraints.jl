module HerbConstraints

using ..HerbGrammar

abstract type PropagatorConstraint <: Constraint end

abstract type LocalConstraint <: Constraint end

include("matchnode.jl")
include("context.jl")

include("comesafter.jl")
include("forbidden.jl")
include("ordered.jl")
include("forbidden_tree.jl")

include("notequals.jl")

export
    AbstractMatchNode,
    MatchNode,
    MatchVar,

    GrammarContext,
    addparent!,
    copy_and_insert,

    PropagatorConstraint,
    LocalConstraint,

    propagate,

    ComesAfter,
    Forbidden,
    Ordered,
    ForbiddenTree,

    NotEquals

end # module HerbConstraints
