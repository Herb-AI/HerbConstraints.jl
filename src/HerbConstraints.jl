module HerbConstraints

using ..HerbGrammar

abstract type PropagatorConstraint <: Constraint end

abstract type LocalConstraint <: Constraint end

@enum PropagateFailureReason unchanged_domain=1
PropagatedDomain = Union{PropagateFailureReason, Vector{Int}}

include("matchfail.jl")
include("matchnode.jl")
include("context.jl")
include("patternmatch.jl")
include("rulenodematch.jl")

include("csg_annotated/csg_annotated.jl")

include("propagatorconstraints/comesafter.jl")
include("propagatorconstraints/forbidden_path.jl")
include("propagatorconstraints/ordered_path.jl")
include("propagatorconstraints/forbidden.jl")
include("propagatorconstraints/ordered.jl")
include("propagatorconstraints/satisfy_condition.jl")
include("propagatorconstraints/satisfy_one_of.jl")

include("localconstraints/local_forbidden.jl")
include("localconstraints/local_ordered.jl")
include("localconstraints/local_satisfy_condition.jl")
include("localconstraints/local_satisfy_one_of.jl")

export
    AbstractMatchNode,
    MatchNode,
    MatchVar,
    matchnode2expr,

    GrammarContext,
    addparent!,
    copy_and_insert,

    contains_var,

    PropagatorConstraint,
    LocalConstraint,
    PropagateFailureReason,
    PropagatedDomain,

    propagate,
    check_tree,

    generateconstraints!,

    ComesAfter,
    ForbiddenPath,
    OrderedPath,
    Forbidden,
    Ordered,
    SatisfyCondition,
    SatisfyOneOf,

    LocalForbidden,
    LocalOrdered,
    LocalSatisfyCondition
    LocalOrdered,
    LocalSatisfyOneOf

end # module HerbConstraints
