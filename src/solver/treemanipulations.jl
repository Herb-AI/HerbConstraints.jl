#TODO: tree manipulations should be callable by passing a `hole`, instead of a `path`
# Related issue: https://github.com/orgs/Herb-AI/projects/6/views/1?pane=issue&itemId=54473456

"""
    remove!(solver::Solver, path::Vector{Int}, rule_index::Int)

Remove `rule_index` from the domain of the hole located at the `path`.
It is assumed the path points to a hole, otherwise an exception will be thrown.
"""
function remove!(solver::Solver, path::Vector{Int}, rule_index::Int)
    #TODO: make a remove method for multiple rules
    #TODO: try to reduce to FixedShapedHole or RuleNode
    hole = get_hole_at_location(solver, path)
    if !hole.domain[rule_index]
        # The rule is not present in the domain, ignore the tree manipulatation
        return
    end
    hole.domain[rule_index] = false
    schedule_all_constraints!(solver)
    fix_point!(solver)
end

"""
    remove_all_but!(solver::Solver, path::Vector{Int}, new_domain::BitVector)

Reduce the domain of the hole located at the `path`, to the `new_domain`.
It is assumed the path points to a hole, otherwise an exception will be thrown.
It is assumed new_domain ⊆ domain. For example: [1, 0, 1, 0] ⊆ [1, 0, 1, 1]
"""
function remove_all_but!(solver::Solver, path::Vector{Int}, new_domain::BitVector)
    hole = get_hole_at_location(solver, path)
    if hole.domain == new_domain @warn "'remove_all_but' was called with trivial arguments" end
    @assert is_subdomain(new_domain, hole.domain) "($new_domain) ⊈ ($(hole.domain)) The remaining rules are required to be a subdomain of the hole to remove from"
    hole.domain = new_domain
    simplify_hole!(solver, path)
    schedule_all_constraints!(solver)
    fix_point!(solver)
end

"""
    substitute!(solver::Solver, path::Vector{Int}, new_node::AbstractRuleNode)

Substitute the node at the `path`, with a `new_node`
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
    schedule_all_constraints!(solver)
    fix_point!(solver)
end

"""
Takes a [Hole](@ref) and tries to simplify it to a [FixedShapedHole](@ref) or [RuleNode](@ref)
"""
function simplify_hole!(solver::Solver, path::Vector{Int})
    #TODO: unit test this
    hole = get_hole_at_location(solver, path)
    grammar = get_grammar(solver)
    if hole isa FixedShapedHole
        if sum(hole.domain) == 1
            new_node = RuleNode(findfirst(hole.domain), hole.children)
            substitute!(solver, path, new_node)
        end
    elseif hole isa VariableShapedHole
        if sum(hole.domain) == 1
            new_node = RuleNode(findfirst(hole.domain), grammar)
            substitute!(solver, path, new_node)
        elseif is_subdomain(hole.domain, grammar.bychildtypes[findfirst(hole.domain)])
            new_node = FixedShapedHole(hole.domain, grammar)
            substitute!(solver, path, new_node)
        end
    else
        @assert !isnothing(hole) "No node exists at path $path in the current state"
        @warn "Attempted to simplify node type: $(typeof(hole))"
    end
end