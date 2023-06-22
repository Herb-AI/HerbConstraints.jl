module HerbConstraints

using ..HerbGrammar

abstract type PropagatorConstraint <: Constraint end

abstract type LocalConstraint <: Constraint end

@enum PropagateFailureReason unchanged_domain=1
PropagatedDomain = Union{PropagateFailureReason, Vector{Int}}

global prop_count = 0
global prop_skip_count = 0
global prop_local_count = 0
global prop_skip_local_count = 0

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
include("propagatorconstraints/condition.jl")
include("propagatorconstraints/one_of.jl")

include("localconstraints/local_forbidden.jl")
include("localconstraints/local_ordered.jl")
include("localconstraints/local_condition.jl")
include("localconstraints/local_one_of.jl")

function get_benchmarking_counters()
    return prop_count, prop_skip_count, prop_local_count, prop_skip_local_count
end

function reset_benchmarking_counters()
    global prop_count = 0
    global prop_skip_count = 0
    global prop_local_count = 0
    global prop_skip_local_count = 0
end

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
    Condition,
    OneOf,

    LocalForbidden,
    LocalOrdered,
    LocalCondition,
    LocalOrdered,
    LocalOneOf,

    get_benchmarking_counters,
    reset_benchmarking_counters  

end # module HerbConstraints
