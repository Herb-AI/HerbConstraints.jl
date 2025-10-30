struct ASPSolver <: Solver
    grammar::AbstractGrammar
    tree::Union{RuleNode,StateHole}
    solutions::Vector{Dict{Int64,Int64}} #vector of dictionaries with key=node and value=matching rule index
    tmp_file_name::String
end

get_name(::ASPSolver) = "ASPSolver"

get_tree(solver::ASPSolver) = solver.tree

get_grammar(solver::ASPSolver) = solver.grammar

get_filename(solver::ASPSolver) = solver.tmp_file_name

get_resultsfile(solver::ASPSolver) = replace(get_filename(solver), ".lp" => "_res.lp")

ASPSolver(grammar, tree) = ASPSolver(grammar, tree, Vector{Dict{Int32,Int32}}(), "__tmp_asp_file.lp")

function solve(solver::ASPSolver, write_to_file::Bool=false)
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
    run(pipeline(ignorestatus(`$(Clingo_jll.clingo()) --models 0`), stdin=buffer, stdout=asp_output))
    extract_solutions(solver, split(String(take!(asp_output)), "\n"))
    if write_to_file
        # Write the asp program to a file
        open(get_filename(solver), "w") do file
            write(file, String(take!(buffer)))
        end
        # Write the asp output to a file
        open(get_resultsfile(solver), "w") do file
            write(file, String(take!(asp_output)))
        end
    end
end

function extract_solutions_from_file(solver::ASPSolver)
    open(get_resultsfile(solver), "r") do file
        extract_solutions(solver, eachline(file))
    end
end

function extract_solutions(solver::ASPSolver, output_lines)
    current_solution = Dict{Int64,Int64}()
    for line in output_lines
        if startswith(line, "node")
            node_assignments = split(line, " ")
            for node in node_assignments
                m = match(r"node\((\d+),(\d+)\)", node)
                current_solution[parse(Int, m.captures[1])] = parse(Int, m.captures[2])
            end
            push!(solver.solutions, current_solution)
        elseif startswith(line, "SATISFIABLE")
            break
        end
    end
end
