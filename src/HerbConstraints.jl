module HerbConstraints

using HerbCore
using HerbGrammar
using DataStructures
using MLStyle

"""
    Abstract type GrammarConstraint <: Constraint end

Abstract type representing all user-defined constraints.
Each grammar constraint has a related [LocalConstraint](@ref) that is responsible for propagating the constraint at a specific location in the tree.
Grammar constraints should implement `on_new_node` to post a [LocalConstraint](@ref) at that new node
"""
abstract type GrammarConstraint <: Constraint end

"""
    abstract type LocalConstraint <: Constraint

Abstract type representing all local constraints.
Local constraints correspond to a specific (partial) [`AbstractRuleNode`](@ref) tree.
Each local constraint contains a `path` to a specific location in the tree.  

Each local constraint should implement a [`propagate!`](@ref)-function.
Inside the [`propagate!`](@ref) function, the constraint can use the following solver functions:
- `remove!`: Elementary tree manipulation. Removes a value from a domain. (other tree manipulations are: `remove_above!`, `remove_below!`, `remove_all_but!`)
- `deactivate!`: Prevent repropagation. Call this as soon as the constraint is satisfied.
- `mark_infeasible!`: Report a non-trivial inconsistency. Call this if the constraint can never be satisfied. An empty domain is considered a trivial inconsistency, such inconsistencies are already handled by tree manipulations.
- `is_feasible`: Check if the current tree is still feasible. Return from the propagate function, as soon as infeasibility is detected.
"""
abstract type LocalConstraint <: Constraint end

include("csg_annotated/csg_annotated.jl")

include("varnode.jl")
include("domainrulenode.jl")

include("solver/solver.jl")
include("solver/solverstatistics.jl")
include("solver/generic_solver/state.jl")
include("solver/generic_solver/generic_solver.jl")
include("solver/generic_solver/treemanipulations.jl")

include("solver/fixed_shaped_solver/state_manager.jl")
include("solver/fixed_shaped_solver/state_sparse_set.jl")
include("solver/fixed_shaped_solver/state_fixed_shaped_hole.jl")
include("solver/fixed_shaped_solver/fixed_shaped_solver.jl")
include("solver/fixed_shaped_solver/fixed_shaped_solver_treemanipulations.jl")
include("solver/domainutils.jl")

include("patternmatch.jl")
include("lessthanorequal.jl")

include("localconstraints/local_forbidden.jl")
include("localconstraints/local_ordered.jl")

include("grammarconstraints/forbidden.jl")
include("grammarconstraints/ordered.jl")


export
    GrammarConstraint,
    LocalConstraint,

    DomainRuleNode,
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
    GenericSolver,
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
    get_intersection,

    #solverstatistics
    track!,

    #functions related to stateful objects
    restore!,
    make_state_int,
    get_value,
    set_value!,
    increment!,
    decrement!,

    #fixed shaped solver
    next_solution!,
    FixedShapedSolver,

    #state fixed shaped hole
    StateFixedShapedHole,
    statefixedshapedhole2rulenode

end # module HerbConstraints
