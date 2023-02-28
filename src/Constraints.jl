module Constraints

using ..Grammars

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

end # module Constraints
