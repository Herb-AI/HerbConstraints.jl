using HerbCore
using HerbGrammar
using DataStructures

"""
    Solver

Maintains a feasible partial program in a [`State`](@ref). A [`ProgramIterator`](@ref) may manipulate the partial tree with the following functions:
- `remove!`
- `substitute!`
- `fill!`
"""
mutable struct Solver
    grammar::Grammar
    state::Union{State, Nothing}
    schedule::PriorityQueue{Constraint, Int}
    #statistics?
end

"""
    Solver(grammar::Grammar)

Constructs a new solver, with an initial state using starting symbol `sym`
"""
function Solver(grammar::Grammar, sym::Symbol)
    solver = Solver(grammar, nothing, Set{Constraint}())
    init_node = Hole(get_domain(grammar, sym))
    new_state!(solver, init_node)
    return solver
end


"""
    schedule(solver::Solver, constraint::Constraint)

Schedules the given `constraint` for propagation
"""
function schedule!(solver::Solver, constraint::Constraint)
    if constraint ∉ keys(solver.schedule)
        enqueue!(solver.schedule, constraint, 99) #TODO: replace `99` with `get_priority(c)`
    end
end

"""
    fix_point!(solver::Solver)

Propagate constraints in the current state until no further dedecutions can be made
"""
function fix_point!(solver::Solver)
    while !isempty(solver.schedule)
        constraint = dequeue!(solver.schedule) 
        #propagate(solver, constraint)
    end
end

"""
    new_state!(solver::Solver, tree::AbstractRuleNode)

Overwrites the current state and propagates constraints on the `tree` from the ground up
"""
function new_state!(solver::Solver, tree::AbstractRuleNode)
    #TODO: rebuild the tree node by node, to add local constraints correctly
    solver.state = State(tree, length(tree), [], complete)
    fix_point!(solver)
end

"""
    save_state!(solver::Solver)

Returns a copy of the current state that can be restored by calling `load_state!(solver, state)`
"""
function save_state!(solver::Solver)::State
    return copy(State)
end

"""
    load_state!(solver::Solver, state::State)

Overwrites the current state with the given `state`
"""
function load_state!(solver::Solver, state::State)
    solver.state = state
end

function get_tree(solver::Solver)::AbstractRuleNode
    return solver.state.tree
end

function get_grammar(solver::Solver)::Grammar
    return solver.grammar
end

"""
    get_state(solver::Solver)::AbstractRuleNode

Get the current state of the solver
"""
function get_state(solver::Solver)::State
    return solver.state
end

#TODO: replace this function. only relevant constraints should be scheduled
function schedule_all_constraints()
    for c ∈ solver.state.constraints
        schedule!(solver, c)
    end
end

#TODO: make a remove method for multiple rules
#TODO: try to reduce to FixedShapedHole or RuleNode
function remove!(solver::Solver, ref::HoleReference, rule_index::Int)
    if !ref.hole.domain[rule_index]
        # The rule is not present in the domain, ignore the tree manipulatation
        return
    end
    ref.hole.domain[rule_index] = false
    schedule_all_constraints()
    fix_point!(solver)
end

function fill!(solver::Solver, ref::HoleReference, rule_index::Int)
    #TODO: implement
    throw("NotImplementedException")
    schedule_all_constraints()
    fix_point!(solver)
end

function remove_all_but!(solver::Solver, ref::HoleReference, rules::BitVector)
    @warn ref.hole.domain == rules "'remove_all_but' called with trivial arguments"
    @assert is_subdomain(rules, ref.hole.domain) "The remaining rules are required to be a subdomain of the hole to remove from"
    ref.hole.domain = rules
    simplify_hole!(solver, ref)
    schedule_all_constraints()
    fix_point!(solver)
end

"""
Substitute the node at the specified `path`, with a `new_node`
"""
function substitute!(solver::Solver, path::Vector{Int}, new_node::AbstractRuleNode)
    #TODO: notify about the domain change of the new_node
    #TODO: notify about the children of the new_node
    #TODO: https://github.com/orgs/Herb-AI/projects/6/views/1?pane=issue&itemId=54383300
    if isempty(path)
        solver.state.tree = new_node
    else
        parent = get_tree(solver)
        for i ∈ path[1:end-1]
            parent = parent.children[i]
        end
        parent.children[path[end]] = new_node
    end
    schedule_all_constraints()
    fix_point!(solver)
end

"""
Takes a [Hole](@ref) and tries to simplify it to a [FixedShapedHole](@ref) or [RuleNode](@ref)
"""
function simplify_hole!(solver::Solver, ref::HoleReference)
    #TODO: unit test this
    (; hole, path) = ref
    if hole isa FixedShapedHole
        if sum(hole.domain) == 1
            new_node = RuleNode(findfirst(domain), hole.children)
            subtitute!(solver, path, new_node)
        end
    end
    if hole isa VariableShapedHole
        if sum(hole.domain) == 1
            new_node = RuleNode(findfirst(domain), grammar)
            subtitute!(solver, path, new_node)
        end
        if is_subdomain(hole.domain, grammar.bychildtypes[findfirst(hole.domain)])
            new_node = FixedShapedHole(hole.domain, get_grammar(solver))
            subtitute!(solver, path, new_node)
        end
    end
end

"""
Checks if `subdomain` is a subdomain of `domain`.

Example: [0, 0, 1, 0] is a subdomain of [0, 1, 1, 1]
"""
function is_subdomain(subdomain::BitVector, domain::BitVector)
    return all(.!subdomain .| domain)
end


"""
Partition a [VariableShapedHole](@ref) into subdomains grouped by childtypes
"""
function partition(hole::VariableShapedHole, grammar::ContextSensitiveGrammar)::Vector{BitVector}
    domain = copy(hole.domain)
    fixed_shaped_domains = []
    while true
        rule = findfirst(domain)
        if isnothing(rule)
            break
        end
        fixed_shaped_domain = grammar.bychildtypes[rule] .& hole.domain
        push!(fixed_shaped_domains, fixed_shaped_domain)
        domain .-= fixed_shaped_domain
    end
    return fixed_shaped_domains
end
