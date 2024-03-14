"""
Representation of a branching constraint in the search tree.
"""
struct Branch
    hole::StateFixedShapedHole
    rule::Int
end


"""
A DFS solver that uses `StateFixedShapedHole`s.
"""
mutable struct FixedShapedSolver
    grammar::Grammar
    sm::StateManager
    tree::Union{RuleNode, StateFixedShapedHole}
    unvisited_branches::Stack{Vector{Branch}}
    nsolutions::Int
    isfeasible::Bool
end


"""
    FixedShapedSolver(grammar::Grammar, fixed_shaped_tree::AbstractRuleNode)
"""
function FixedShapedSolver(grammar::Grammar, fixed_shaped_tree::AbstractRuleNode)
    @assert !contains_variable_shaped_hole(fixed_shaped_tree) "$(fixed_shaped_tree) contains variable shaped holes"
    sm = StateManager()
    tree = StateFixedShapedHole(sm, fixed_shaped_tree)
    unvisited_branches = Stack{Vector{Branch}}() 
    nsolutions = 0
    isfeasible = true
    solver = FixedShapedSolver(grammar, sm, tree, unvisited_branches, nsolutions, isfeasible)
    save_state!(solver)
    push!(unvisited_branches, generate_branches(solver)) #generate initial branches for the root search node
    return solver
end

function is_feasible(solver::FixedShapedSolver)
    return solver.isfeasible
end


function mark_infeasible(solver::FixedShapedSolver)
    solver.isfeasible = false
end


"""
Save the current state of the solver, can restored using `restore!`
"""
function save_state!(solver::FixedShapedSolver)
    save_state!(solver.sm)
end


"""
Restore state of the solver until the last `save_state!`
"""
function restore!(solver::FixedShapedSolver)
    restore!(solver.sm)
end

#TODO: implement more branching schemes
"""
Returns a vector of disjoint branches to expand the search tree at its current state.
Example:
```
# pseudo code
Hole(domain=[2, 4, 5], children=[
    Hole(domain=[1, 6]), 
    Hole(domain=[1, 6])
])
```
A possible branching scheme could be to be split up in three `Branch`ing constraints:
- `Branch(firsthole, 2)`
- `Branch(firsthole, 4)`
- `Branch(firsthole, 5)`
"""
function generate_branches(solver::FixedShapedSolver)::Vector{Branch}
    #omitting `::Vector{Branch}` from `_dfs` speeds up the search by a factor of 2
    function _dfs(node::Union{StateFixedShapedHole, RuleNode}) #::Vector{Branch}
        if node isa StateFixedShapedHole && size(node.domain) > 1
            return [Branch(node, rule) for rule ∈ node.domain]
        end
        for child ∈ node.children
            branches = _dfs(child)
            if !isempty(branches)
                return branches
            end
        end
        return []
    end
    return _dfs(solver.tree)
end


"""
    next_solution!(solver::FixedShapedSolver)

Built-in iterator. Search for the next unvisited solution.
Returns nothing if all solutions have been found already.
"""
function next_solution!(solver::FixedShapedSolver)::Union{AbstractRuleNode, Nothing}
    if solver.nsolutions == 1000000 @warn "FixedShapedSolver is iterating over more than 1000000 solutions..." 
    if solver.nsolutions > 0
        # backtrack from the previous solution
        restore!(solver)
    end
    while length(solver.unvisited_branches) > 0
        branches = top(solver.unvisited_branches)
        if length(branches) > 0
            # current depth has unvisted branches, pick a branch to explore
            branch = pop!(branches)
            save_state!(solver)
            remove_all_but!(branch.hole.domain, branch.rule)
            #TODO: check for feasibility here
            if true == true
                # generate new branches for the new search node
                branches = generate_branches(solver)
                if length(branches) == 0
                    # search node is a solution leaf node, return the solution
                    solver.nsolutions += 1
                    return solver.tree
                else
                    # search node is an internal node, store the branches to visit
                    push!(solver.unvisited_branches, branches)
                end
            else
                # search node is an infeasible leaf node, backtrack
                restore!(solver)
            end
        else
            # search node is an exhausted internal node, backtrack
            restore!(solver)
            pop!(solver.unvisited_branches)
        end
    end
    return nothing
end


"""
    count_solutions(solver::FixedShapedSolver)

Iterate over all solutions and count the number of solutions encountered.
!!! warning:
    Solutions are overwritten. It is not possible to return all the solutions without copying. 
"""
function count_solutions(solver::FixedShapedSolver)
    count = 0
    s = next_solution!(solver)
    while !isnothing(s)
        count += 1
        s = next_solution!(solver)
    end
    return count
end
