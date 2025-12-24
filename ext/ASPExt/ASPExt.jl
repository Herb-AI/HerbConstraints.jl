module ASPExt

import Clingo_jll
import HerbConstraints
import HerbConstraints: ASPSolver, rulenode_to_ASP, get_rulenode, get_grammar, grammar_to_ASP, extract_solutions
import TimerOutputs: @timeit_debug

# docstring in src/solver/asp_solver/asp_solver.jl
function HerbConstraints.solve(solver::ASPSolver)
    @timeit_debug solver.statistics "generate ASP RuleNode" begin
        string_rulenode, _ = rulenode_to_ASP(get_rulenode(solver), get_grammar(solver), 1)
        constraints = grammar_to_ASP(get_grammar(solver))

        asp_input = """
        %%% RuleNode
        $string_rulenode

        %%% Constraints
        $constraints

        %%% Query
        #show node/2.
        """
    end

    buffer = IOBuffer(asp_input)
    asp_output = IOBuffer()
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
            stdout=asp_output
        ))
    end
    extract_solutions(solver, split(String(take!(asp_output)), "\n"))
end

end # module ASPExt
