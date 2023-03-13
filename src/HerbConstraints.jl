module HerbConstraints

using ..HerbGrammar

abstract type PropagatorConstraint <: Constraint end

include("matchnode.jl")

include("comesafter.jl")
include("forbidden.jl")
include("ordered.jl")
include("forbidden_tree.jl")

export
    AbstractMatchNode,
    MatchNode,
    MatchVar,

    PropagatorConstraint,

    propagate,

    ComesAfter,
    Forbidden,
    Ordered,
    ForbiddenTree

end # module HerbConstraints