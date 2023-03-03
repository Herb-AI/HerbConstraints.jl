module HerbConstraints

using ..HerbGrammar

abstract type PropagatorConstraint <: Constraint end

include("comesafter.jl")
include("forbidden.jl")
include("ordered.jl")

export
    PropagatorConstraint,

    propagate,

    ComesAfter,
    Forbidden,
    Ordered

end # module HerbConstraints
