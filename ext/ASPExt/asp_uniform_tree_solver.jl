HerbConstraints.get_name(::ASPSolver) = "ASPSolver"

"""
    get_grammar(solver::ASPSolver)

Get the grammar.
"""
function HerbConstraints.get_grammar(solver::ASPSolver)::AbstractGrammar
    return solver.grammar
end

"""
    get_rulenode(solver::ASPSolver)

Get the RuleNode of the current program. This remains the same instance throughout the entire search.
"""
function get_rulenode(solver::ASPSolver)::AbstractRuleNode
    return solver.uniform_rulenode
end

HerbConstraints.get_tree(solver::ASPSolver) = get_rulenode(solver)

"""
    isfeasible(solver::ASPSolver)

Returns true if no inconsistency has been detected.
"""
function HerbConstraints.isfeasible(solver::ASPSolver)
    return solver.isfeasible
end

"""
    solve(solver::ASPSolver)

Generate all solutions for the given rulenode using ASP solver Clingo.
"""
function HerbConstraints.solve(solver::ASPSolver)
    if !isempty(solver.solutions)
        @warn """
        Calling solve on already-solved `ASPSolver`. Note that `solve` is \
        called already when constructing an `ASPSolver`.
        """
    end
    @timeit_debug solver.statistics "generate ASP RuleNode" begin
        string_rulenode, _ = rulenode_to_ASP(get_rulenode(solver), HerbConstraints.get_grammar(solver), 1)
        constraints = grammar_to_ASP(HerbConstraints.get_grammar(solver))
        comparisons = rulenode_comparisons_asp(solver)

        asp_input = """
        %%% RuleNode
        $string_rulenode
        %%% Comparisons
        $comparisons
        %%% Constraints
        $constraints
        %%% Query
        #show node/2.
        """
    end

    buffer = IOBuffer(asp_input)
    @debug get_rulenode(solver) HerbConstraints.get_grammar(solver) asp_input
    asp_output = IOBuffer()
    errors_and_warnings = IOBuffer()
    @timeit_debug solver.statistics "run Clingo" begin
        run(pipeline(
            # Ignore the status of the command because clingo uses the return
            # code of the CLI to communicate some information about the status
            # of the solve, and, depending on the status, this makes it appear
            # as though the command has failed (exit code != 0)
            #
            # --models 0 means return _all_ models (solutions), not 0 models
            ignorestatus(`$(Clingo_jll.clingo()) --models 0`),
            stdin=buffer,
            stderr=errors_and_warnings,
            stdout=asp_output
        ))
    end

    errors_and_warnings = String(take!(errors_and_warnings))
    if errors_and_warnings != ""
        @warn "Stderr from `clingo`:\n" * errors_and_warnings
    end

    extract_solutions(solver, split(String(take!(asp_output)), "\n"))
end

"""
    extract_solutions(solver::ASPSolver, output_lines)

Extract solutions from the output of Clingo and store them in the `solutions` field of the solver.
"""
function extract_solutions(solver::ASPSolver, output_lines)
    @timeit_debug solver.statistics "extract solutions" begin
        for line in output_lines
            if startswith(line, "node")
                @debug "Parsing a node" line
                current_solution = Dict{Int64,Int64}()
                node_assignments = split(line, " ")
                for node in node_assignments
                    m = match(r"node\((?<asp_id>\d+),(?<grammar_rule_index>\d+)\)", node)
                    asp_id, grammar_rule_index = m.captures
                    @debug "Found one match" asp_id grammar_rule_index
                    current_solution[parse(Int, asp_id)] = parse(Int, grammar_rule_index)
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
end
