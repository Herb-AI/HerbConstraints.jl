#TODO: tree manipulations should be callable by passing a `hole`, instead of a `path`
# Related issue: https://github.com/orgs/Herb-AI/projects/6/views/1?pane=issue&itemId=54473456

#TODO: unit test all tree manipulatations

"""
    remove!(solver::Solver, path::Vector{Int}, rule_index::Int)

Remove `rule_index` from the domain of the hole located at the `path`.
It is assumed the path points to a hole, otherwise an exception will be thrown.
"""
function remove!(solver::Solver, path::Vector{Int}, rule_index::Int)
    hole = get_hole_at_location(solver, path)
    if !hole.domain[rule_index]
        # The rule is not present in the domain, ignore the tree manipulatation
        return
    end
    hole.domain[rule_index] = false
    simplify_hole!(solver, path)
    notify_tree_manipulation(solver, path)
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
    notify_tree_manipulation(solver, path)
    fix_point!(solver)
end

"""
    remove_above!(solver::Solver, path::Vector{Int}, rule_index::Int)

Reduce the domain of the hole located at the `path` by removing all rules indices above `rule_index`
Example:
`rule_index` = 2. 
`hole` with domain [1, 1, 0, 1] gets reduced to [1, 0, 0, 0] and gets simplified to a `RuleNode`
"""
function remove_above!(solver::Solver, path::Vector{Int}, rule_index::Int)
    hole = get_hole_at_location(solver, path)
    highest_ind = findlast(hole.domain)
    if highest_ind < rule_index
        # e.g. domain: [0, 1, 1, 0, 0, 0] rule_index: 4
        # The tree manipulatation won't have any effect, ignore the tree manipulatation
        return
    end
    for r ∈ rule_index+1:length(hole.domain)
        hole.domain[r] = false
    end
    simplify_hole!(solver, path)
    notify_tree_manipulation(solver, path)
    fix_point!(solver)
end

"""
    remove_below!(solver::Solver, path::Vector{Int}, rule_index::Int)

Reduce the domain of the hole located at the `path` by removing all rules indices below `rule_index`
Example:
`rule_index` = 2. 
`hole` with domain [1, 1, 0, 1] gets reduced to [0, 1, 0, 1]
"""
function remove_below!(solver::Solver, path::Vector{Int}, rule_index::Int)
    hole = get_hole_at_location(solver, path)
    lowest_ind = findfirst(hole.domain)
    if lowest_ind > rule_index
        # e.g. domain: [0, 0, 0, 1, 1, 0] rule_index: 2
        # The tree manipulatation won't have any effect, ignore the tree manipulatation
        return
    end
    for r ∈ 1:rule_index-1
        hole.domain[r] = false
    end
    simplify_hole!(solver, path)
    notify_tree_manipulation(solver, path)
    fix_point!(solver)
end

"""
    fill_hole!(solver::Solver, path::Vector{Int}, rule_index::Int)

Fill in the hole located at the `path` with rule `rule_index`.
It is assumed the path points to a hole, otherwise an exception will be thrown.
It is assumed rule_index ∈ hole.domain
"""
function fill_hole!(solver::Solver, path::Vector{Int}, rule_index::Int)
    hole = get_hole_at_location(solver, path)
    @assert hole.domain[rule_index] "Hole $hole cannot be filled with rule $rule_index"
    @assert hole isa FixedShapedHole "fill_hole! is only supported for filling in FixedShapedHoles. (reason: filling a VariableShapedHole would create new holes and currently 'simplify_hole!' is the only place where new holes can appear)"
    new_node = RuleNode(rule_index, hole.children)
    substitute!(solver, path, new_node)
end


"""
    substitute!(solver::Solver, path::Vector{Int}, new_node::AbstractRuleNode)

Substitute the node at the `path`, with a `new_node`
"""
function substitute!(solver::Solver, path::Vector{Int}, new_node::AbstractRuleNode)
    #TODO: add a parameter that indicates if the children of the new_node are already known to the solver. For example, when filling in a fixed shaped hole
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
    if get_tree_size(solver) > get_max_size(solver)
        mark_infeasible(solver)
        return
    end
    notify_tree_manipulation(solver, path)
    fix_point!(solver)
end

"""
Takes a [Hole](@ref) and tries to simplify it to a [FixedShapedHole](@ref) or [RuleNode](@ref).
If the domain of the hole is empty, the state will be marked as infeasible
"""
function simplify_hole!(solver::Solver, path::Vector{Int})
    hole = get_hole_at_location(solver, path)
    grammar = get_grammar(solver)
    new_node = nothing
    domain_size = sum(hole.domain)
    if domain_size == 0
        mark_infeasible(solver)
        return
    elseif hole isa FixedShapedHole
        if domain_size == 1
            new_node = RuleNode(findfirst(hole.domain), hole.children)
        end
    elseif hole isa VariableShapedHole
        if domain_size == 1
            new_node = RuleNode(findfirst(hole.domain), grammar)
        elseif is_subdomain(hole.domain, grammar.bychildtypes[findfirst(hole.domain)])
            new_node = FixedShapedHole(hole.domain, grammar)
        end
    else
        @assert !isnothing(hole) "No node exists at path $path in the current state"
        @warn "Attempted to simplify node type: $(typeof(hole))"
    end

    #the hole will be simplified and replaced with a `new_node`
    if !isnothing(new_node)
        substitute!(solver, path, new_node)
        for i ∈ 1:length(new_node.children)
            notify_new_node(solver, push!(copy(path), i))
        end
    end
end
