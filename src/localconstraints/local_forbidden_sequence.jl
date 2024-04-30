"""
    LocalForbiddenSequence <: AbstractGrammarConstraint

Forbids the given `sequence` of rule nodes ending at the node at the `path`.
"""
struct LocalForbiddenSequence <: AbstractGrammarConstraint
    path::Vector{Int}
    sequence::Vector{Int}
    ignore_if::Vector{Int}
end

"""
    function propagate!(solver::Solver, c::LocalForbiddenSequence)

"""
function propagate!(solver::Solver, c::LocalForbiddenSequence)
    throw("NotImplemented")
    #TODO:
    # root = get_tree(solver)
    # sequence = [root]
    # forbidden_assignments = Vector{Tuple{AbstractHole, Int}}()
    # for i in c.path
    #     push!(sequence[end].children[i])
    # end
    # index = length(c.sequence)
    # while index > 0
    #     if isempty(sequence)
    #         set_infeasible!(solver)
    #         return
    #     end
    #     node = pop!(sequence)
    #     if isfilled(node)
    #         if (c.sequence[index] == get_rule(node))
    #             index -= 1
    #         end
    #     else
    #         if node.domain[c.sequence[index]]
    #             push!(forbidden_assignments, (node, c.sequence[index]))
    #             index -= 1
    #         end
    #     end
    # end
    # if length(forbidden_assignments) <= 1
    #     deactivate!(solver, c)
    #     if length(forbidden_assignments) == 1
    #         hole, rule = forbidden_assignments[1]
    #         path = get_path(root, hole)
    #         remove!(solver, path, rule)
    #     end
    # end
end
