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

ASPSolver(grammar, tree) = ASPSolver(grammar, tree, Vector{Dict{Int32,Int32}}(), "__tmp_asp_file.lp")

function prepare_ASP(solver::ASPSolver)
    string_tree, _ = tree_to_ASP(get_tree(solver), get_grammar(solver), 1)

    open(get_filename(solver), "w") do file
        write(file, "%%% Tree\n")
        write(file, string_tree)
        write(file, "\n%%% Constraints\n")
        constraints = to_ASP(get_grammar(solver))
        write(file, constraints)
        write(file, "#show node/2.\n")
    end
end

get_resultsfile(solver::ASPSolver) = replace(get_filename(solver), ".lp" => "_res.lp")

function extract_solutions!(solver::ASPSolver)
    open(get_resultsfile(solver), "r") do file
        current_solution = Dict{Int64,Int64}()
        for line in eachline(file)
            if startswith(line, "Answer")
                if !isempty(current_solution)
                    push!(solver.solutions, current_solution)
                end
                current_solution = Dict{Int64,Int64}()
            elseif startswith(line, "node")
                node_assignments = split(line, " ")
                for node in node_assignments
                    m = match(r"node\((\d+),(\d+)\)", node)
                    current_solution[parse(Int, m.captures[1])] = parse(Int, m.captures[2])
                end
            elseif startswith(line, "SATISFIABLE")
                break
            end
        end
    end
end

function find_solutions!(solver::ASPSolver)
    prepare_ASP(solver)

    source_file = get_filename(solver)
    res_file = get_resultsfile(solver)
    run(`clingo --models 0 ./$source_file \> ./$res_file`)

    extract_solutions!(solver)
end
