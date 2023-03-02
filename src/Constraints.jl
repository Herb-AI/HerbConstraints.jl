module Constraints

using ..Grammars

abstract type PropagatorConstraint <: Constraint end

include("comesafter.jl")
include("forbidden.jl")
include("ordered.jl")
include("forbidden_tree.jl")

export
    PropagatorConstraint,

    propagate,

    _match_expr, # Temporary

    ComesAfter,
    Forbidden,
    Ordered,
    ForbiddenTree

end # module Constraints
