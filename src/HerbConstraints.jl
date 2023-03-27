module HerbConstraints

using ..HerbGrammar

abstract type PropagatorConstraint <: Constraint end

abstract type LocalConstraint <: Constraint end

include("matchfail.jl")
include("matchnode.jl")
include("context.jl")
include("patternmatch.jl")
include("rulenodematch.jl")

include("propagatorconstraints/comesafter.jl")
include("propagatorconstraints/forbidden.jl")
include("propagatorconstraints/ordered.jl")
include("propagatorconstraints/forbidden_tree.jl")

include("localconstraints/notequals.jl")
include("localconstraints/commutativity.jl")

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

    NotEquals,
    Commutativity

end # module HerbConstraints
