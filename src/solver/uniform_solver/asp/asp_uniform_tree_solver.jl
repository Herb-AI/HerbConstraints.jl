using Clingo_jll

mutable struct ASPSolver <: Solver
    grammar::AbstractGrammar
    tree::Union{RuleNode,UniformHole,StateHole}
    solutions::Vector{Dict{Int64,Int64}} #vector of dictionaries with key=node and value=matching rule index
    isfeasible::Bool
    statistics::Union{TimerOutput, Nothing}
end

"""
    ASPSolver(grammar::AbstractGrammar, fixed_shaped_tree::AbstractRuleNode)
"""
function ASPSolver(grammar::AbstractGrammar, fixed_shaped_tree::AbstractRuleNode; with_statistics=false)
    @assert !contains_nonuniform_hole(fixed_shaped_tree) "$(fixed_shaped_tree) contains non-uniform holes"
    statistics = @match with_statistics begin
        ::TimerOutput => with_statistics
        ::Bool => with_statistics ? TimerOutput("ASP Solver") : nothing
        ::Nothing => nothing
    end
    solver = ASPSolver(grammar, fixed_shaped_tree,  Vector{Dict{Int32,Int32}}(), false, statistics)
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
    get_tree(solver::ASPSolver)

Get the root of the tree. This remains the same instance throughout the entire search.
"""
function get_tree(solver::ASPSolver)::AbstractRuleNode
    return solver.tree
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

Generate all solutions for the given tree using ASP solver Clingo.
"""
function solve(solver::ASPSolver)
    @timeit_debug solver.statistics "generate ASP tree" begin end
    string_tree, _ = tree_to_ASP(get_tree(solver), get_grammar(solver), 1)
    constraints = to_ASP(get_grammar(solver))
    asp_input = """
%%% Tree
$string_tree

%%% Constraints
$constraints

%%% Query
#show node/2.
"""
    buffer = IOBuffer(asp_input)
    asp_output = IOBuffer()
    @timeit_debug solver.statistics "run Clingo" begin end
    run(pipeline(ignorestatus(`$(Clingo_jll.clingo()) --models 0`), stdin=buffer, stdout=asp_output))
    extract_solutions(solver, split(String(take!(asp_output)), "\n"))
end

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
