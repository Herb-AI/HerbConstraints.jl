"""
    $(TYPEDEF)

A solver that uses [Answer Set
Programming](https://en.wikipedia.org/wiki/Answer_set_programming) to yield all
solutions for a given uniform tree.

$(TYPEDFIELDS)

An ASPSolver is instantiated with a `grammar` and a `ruleNode`, automatically
calling the `solve` function to retrieve all `solutions`. The constraints of
the `grammar` and the `ruleNode` are transformed to ASP rules. Then, Clingo_jll
is used to generate all solutions for this Answer Set Program. These
`solutions` can then be iterated. 
    
To use the ASP Solver, Clingo_jll must be manually specified to be used, which
automaticlaly loads the ASPExt extension module of HerbConstraints.

```julia
julia> using Clingo_jll
```
"""
mutable struct ASPSolver <: Solver
    "The grammar of the program we are solving. It likely has constraints."
    grammar::AbstractGrammar
    "The root of the uniform tree."
    ruleNode::Union{RuleNode,UniformHole,StateHole}
    "All solutions (concrete programs) for the current `ruleNode` given the
    `grammar` and its constraints."
    solutions::Vector{Dict{Int64,Int64}} #vector of dictionaries with key=node and value=matching rule index
    "Whether the solver is in a feasible state."
    isfeasible::Bool
    "Statistics about the solving process."
    statistics::Union{TimerOutput,Nothing}
end

"""
    ASPSolver(grammar::AbstractGrammar, uniform_rulenode::AbstractRuleNode; with_statistics=false)

Initialize and solve an `ASPSolver` with a `grammar` and `uniform_rulenode`.

!!! note
    In the current implementation, all solutions are collected at initialization.
    Note that this might mean that the time taken to return the first solution is
    significant for large uniform trees.
"""
function HerbConstraints.ASPSolver(grammar::AbstractGrammar, uniform_rulenode::AbstractRuleNode; with_statistics=false)
    if contains_nonuniform_hole(uniform_rulenode)
        error("$(uniform_rulenode) contains non-uniform holes. The ASPSolver only works with uniform trees.")
    end

    statistics = @match with_statistics begin
        ::TimerOutput => with_statistics
        ::Bool => with_statistics ? TimerOutput("ASP Solver") : nothing
        ::Nothing => nothing
    end

    solver = new(grammar, uniform_rulenode, Vector{Dict{Int32,Int32}}(), false, statistics)
    solve(solver)

    return solver
end

get_name(::ASPSolver) = "ASPSolver"

"""
    get_grammar(solver::ASPSolver)

Get the grammar.
"""
function get_grammar(solver::ASPSolver)::AbstractGrammar
    return solver.grammar
end

"""
    get_rulenode(solver::ASPSolver)

Get the RuleNode of the current program. This remains the same instance throughout the entire search.
"""
function get_rulenode(solver::ASPSolver)::AbstractRuleNode
    return solver.ruleNode
end

"""
    isfeasible(solver::ASPSolver)

Returns true if no inconsistency has been detected.
"""
function isfeasible(solver::ASPSolver)
    return solver.isfeasible
end

"""
    solve(solver::ASPSolver)

Generate all solutions for the given rulenode using ASP solver Clingo.

!!! note
    This function requires the `Clingo_jll` package to be installed.
"""
function solve end

"""
    extract_solutions(solver::ASPSolver, output_lines)

Extract solutions from the output of Clingo and store them in the `solutions` field of the solver.
"""
function extract_solutions(solver::ASPSolver, output_lines)
    @timeit_debug solver.statistics "extract solutions" begin end
    for line in output_lines
        if startswith(line, "node")
            current_solution = Dict{Int64,Int64}()
            node_assignments = split(line, " ")
            for node in node_assignments
                m = match(r"node\((\d+),(\d+)\)", node)
                current_solution[parse(Int, m.captures[1])] = parse(Int, m.captures[2])
            end
            push!(solver.solutions, current_solution)
        elseif startswith(line, "SATISFIABLE")
            solver.isfeasible = true
            break
        elseif startswith(line, "UNSATISFIABLE")
            solver.isfeasible = false
            break
        end
    end
end
