module HerbConstraints

using ..HerbGrammar

abstract type PropagatorConstraint <: Constraint end

abstract type LocalConstraint <: Constraint end

include("matchfail.jl")
include("patternnode.jl")
include("context.jl")
include("patternmatch.jl")
include("rulenodematch.jl")

include("propagatorconstraints/comesafter.jl")
include("propagatorconstraints/forbidden.jl")
include("propagatorconstraints/ordered.jl")
include("propagatorconstraints/forbidden_tree.jl")

include("localconstraints/notequals.jl")

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
