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
