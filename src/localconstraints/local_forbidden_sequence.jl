"""
    LocalForbiddenSequence <: AbstractLocalConstraint

Forbids the given `sequence` of rule nodes ending at the node at the `path`.
If any of the rules in `ignore_if` appears in the sequence, the constraint is ignored.
"""
struct LocalForbiddenSequence <: AbstractLocalConstraint
    path::Vector{Int}
    sequence::Vector{Int}
    ignore_if::Vector{Int}
end

"""
    function propagate!(solver::Solver, c::LocalForbiddenSequence)

"""
function propagate!(solver::Solver, c::LocalForbiddenSequence)
    #TODO: it would be better to precompute the list of `nodes` on the path.
    # however, in the GenericSolver, uniform holes might be replaced with a rule node, so the instances might change
    nodes = get_nodes_on_path(get_tree(solver), c.path)

    # c.sequence = [1, 2, 3]
    # c.nodes = [RuleNode(1), RuleNode(2), UniformHole(1, 2), UniformHole(2, 4), RuleNode(3)]
    # c.nodes = [1, {2, 4}, 1, {2, 4}, 3]

    # Smallest match
    forbidden_assignments = Vector{Tuple{Int, Any}}()
    i = length(c.sequence)
    for (path_idx, node) ∈ Iterators.reverse(enumerate(nodes))
        forbidden_rule = c.sequence[i]
        if (node isa RuleNode) || (node isa StateHole && isfilled(node)) #TODO: in herbcore: isfilled(::AbstractHole) = false
            rule = get_rule(node)
            if (rule ∈ c.ignore_if)
                deactivate!(solver, c)
                return
            elseif (rule == forbidden_rule)
                i -= 1
            end
        else
            if node.domain[forbidden_rule]
                push!(forbidden_assignments, (path_idx, forbidden_rule))
                i -= 1
            else
                for r ∈ c.ignore_if
                    if node.domain[r]
                        rules = [r for r ∈ findall(node.domain) if r ∉ c.ignore_if]
                        if !isempty(rules)
                            push!(forbidden_assignments, (path_idx, rules))
                            i -= 1
                        end
                        break
                    end
                end
            end
        end
        if i == 0
            break
        end
    end
    if i > 0
        deactivate!(solver, c)
        return
    end
    if length(forbidden_assignments) == 0
        set_infeasible!(solver)
        return
    elseif length(forbidden_assignments) == 1
        path_idx, rule = forbidden_assignments[1]
        remove!(solver, c.path[1:path_idx-1], rule)
        propagate!(solver, c)
        return
    end

    # Smallest match with a maximum of 1 hole (Optional, slightly stronger inference without making all possible matches) 
    i = length(c.sequence)
    forbidden_assignment = nothing
    for (path_idx, node) ∈ Iterators.reverse(enumerate(nodes))
        forbidden_rule = c.sequence[i]
        if (node isa RuleNode) || (node isa StateHole && isfilled(node)) #TODO: in herbcore: isfilled(::AbstractHole) = false
            rule = get_rule(node)
            if (rule ∈ c.ignore_if)
                return
            elseif (rule == forbidden_rule)
                i -= 1
            end
        elseif isnothing(forbidden_assignment)
            forbidden_assignment = (path_idx, forbidden_rule)
            i -= 1
        end
    end
    if i > 0
        return
    end
    if isnothing(forbidden_assignment)
        set_infeasible!(solver)
        return
    end
    path_idx, rule = forbidden_assignment
    remove!(solver, c.path[1:path_idx-1], rule)
    propagate!(solver, c)
end


"""
    function get_nodes_on_path(root::AbstractRuleNode, path::Vector{Int})::Vector{AbstractRuleNode}

Gets a list of nodes on the `path`, starting (and including) the `root`.
"""
function get_nodes_on_path(node::AbstractRuleNode, path::Vector{Int})::Vector{AbstractRuleNode}
    #TODO: HerbCore has a similar function: `get_rulesequence` that was implemented before the concept of uniformholes. That function should probably be deleted.
    nodes = Vector{AbstractRuleNode}()
    push!(nodes, node)
    for i ∈ path
        node = node.children[i]
        push!(nodes, node)
    end
    return nodes
end
