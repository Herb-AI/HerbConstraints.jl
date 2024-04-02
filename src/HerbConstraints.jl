module HerbConstraints

using HerbCore
using HerbGrammar
using DataStructures
using MLStyle

"""
    abstract type GrammarConstraint <: Constraint

Abstract type representing all user-defined constraints.
Each grammar constraint has a related [LocalConstraint](@ref) that is responsible for propagating the constraint at a specific location in the tree.
Grammar constraints should implement `on_new_node` to post a [`LocalConstraint`](@ref) at that new node
"""
abstract type GrammarConstraint <: Constraint end

"""
    abstract type LocalConstraint <: Constraint

Abstract type representing all local constraints.
Local constraints correspond to a specific (partial) [`AbstractRuleNode`](@ref) tree.
Each local constraint contains a `path` to a specific location in the tree.  
Each local constraint should implement a [`propagate!`](@ref)-function.

!!! warning
    By default, [`LocalConstraint`](@ref)s are only propagated once.
    Constraints that have to be propagated more frequently should subscribe to an event. This part of the solver is still WIP.
    Currently, the solver supports only one type of subscription: `propagate_on_tree_manipulation!`.
"""
abstract type LocalConstraint <: Constraint end

include("csg_annotated/csg_annotated.jl")

include("varnode.jl")
include("patternmatch.jl")

include("solver/solverstatistics.jl")
include("solver/state.jl")
include("solver/solver.jl")
include("solver/treemanipulations.jl")
include("solver/domainutils.jl")

include("lessthanorequal.jl")

include("localconstraints/local_forbidden.jl")
include("localconstraints/local_ordered.jl")

include("grammarconstraints/forbidden.jl")
include("grammarconstraints/ordered.jl")


export
    GrammarConstraint,
    LocalConstraint,

    VarNode,
    pattern_match,
    check_tree,
    
    #grammar constraints
    Forbidden,
    Ordered,

    #local constraints
    LocalForbidden,
    LocalOrdered,

    #public solver functions
    Solver,
    State,
    new_state!,
    save_state!,
    load_state!,
    is_feasible,
    get_state,
    get_tree,
    get_grammar,
    get_state,
    get_node_at_location,
    get_hole_at_location,
    get_max_depth,
    get_max_size,
    get_tree_size,

    #tree manipulations
    remove!,
    fill_hole!,
    remove_all_but!,
    substitute!,

    #domainutils
    is_subdomain,
    partition,
    are_disjoint,

    #solverstatistics
    track!

end # module HerbConstraints
