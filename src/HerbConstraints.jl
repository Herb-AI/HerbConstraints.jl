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

include("propagatorconstraints/comesafter.jl")
include("propagatorconstraints/forbidden_path.jl")
include("propagatorconstraints/ordered_path.jl")
include("propagatorconstraints/forbidden.jl")
include("propagatorconstraints/ordered.jl")

include("localconstraints/local_forbidden.jl")
include("localconstraints/local_ordered.jl")

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

    propagate,
    check_tree,

    ComesAfter,
    ForbiddenPath,
    OrderedPath,
    Forbidden,
    Ordered,

    LocalForbidden,
    LocalOrdered

    get_benchmarking_counters,
    reset_benchmarking_counters  

end # module HerbConstraints
