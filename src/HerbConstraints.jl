module HerbConstraints

using ..HerbCore
using ..HerbGrammar

"""
    PropagatorConstraint <: Constraint

Abstract type representing all propagator constraints.
Each propagator constraint has an implementation of a [`propagate`](@ref)-function that takes

- the [`PropagatorConstraint`](@ref)
- a [`Grammar`](@ref)
- a [`GrammarContext`](@ref), which most importantly contains the tree and the location 
  in the tree where propagation should take place.
- The `domain` which the [`propagate`](@ref)-function prunes. 

The [`propagate`](@ref)-function returns a tuple containing

- The pruned `domain`
- A list of new [`LocalConstraint`](@ref)s
"""
abstract type PropagatorConstraint <: Constraint end

"""
    LocalConstraint <: Constraint

Abstract type representing all local constraints.
Local constraints correspond to a specific (partial) [`AbstractRuleNode`](@ref) tree.
Each local constraint contains a `path` to a specific location in the tree.  
Each local constraint has an implementation of a [`propagate`](@ref)-function that takes

- the [`LocalConstraint`](@ref)
- a [`Grammar`](@ref)
- a [`GrammarContext`](@ref), which most importantly contains the tree and the location 
  in the tree where propagation should take place.
- The `domain` which the [`propagate`](@ref)-function prunes. 

The [`propagate`](@ref)-function returns a tuple containing

- The pruned `domain`
- A list of new [`LocalConstraint`](@ref)s

!!! warning
    By default, [`LocalConstraint`](@ref)s are only propagated once.
    Constraints that have to be propagated more frequently should return 
    themselves in the list of new local constraints.
"""
abstract type LocalConstraint <: Constraint end

include("matchfail.jl")
include("matchnode.jl")
include("context.jl")
include("patternmatch.jl")
include("rulenodematch.jl")

include("propagatorconstraints/comesafter.jl")
include("propagatorconstraints/forbidden_path.jl")
include("propagatorconstraints/require_on_left.jl")
include("propagatorconstraints/forbidden.jl")
include("propagatorconstraints/ordered.jl")

include("localconstraints/local_forbidden.jl")
include("localconstraints/local_ordered.jl")

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
    RequireOnLeft,
    Forbidden,
    Ordered,

    LocalForbidden,
    LocalOrdered

end # module HerbConstraints
