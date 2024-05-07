"""
    Ordered <: AbstractGrammarConstraint

A [`AbstractGrammarConstraint`](@ref) that enforces a specific order in [`MatchVar`](@ref) 
assignments in the pattern defined by `tree`.
Nodes in the pattern can either be a [`RuleNode`](@ref), which contains a rule index corresponding to the 
rule index in the [`AbstractGrammar`](@ref) and the appropriate number of children.
It can also contain a [`VarNode`](@ref), which contains a single identifier symbol.
A [`VarNode`](@ref) can match any subtree. 
If there are multiple instances of the same variable in the pattern, the matched subtrees must be identical.

The `order` defines an order between the variable assignments. 
For example, if the order is `[x, y]`, the constraint will require 
the assignment to `x` to be less than or equal to the assignment to `y`.
The order is recursively defined by [`RuleNode`](@ref) indices. 
For more information, see [`Base.isless(rn₁::AbstractRuleNode, rn₂::AbstractRuleNode)`](@ref).

For example, consider the tree `1(a, 2(b, 3(c, 4))))`:

- `Ordered(RuleNode(3, [VarNode(:v), VarNode(:w)]), [:v, :w])` removes every rule 
    with an index of 5 or greater from the domain of `c`, since that would make the index of the 
    assignment to `v` greater than the index of the assignment to `w`, violating the order.
- `Ordered(RuleNode(3, [VarNode(:v), VarNode(:w)]), [:w, :v])` removes every rule 
    with an index of 4 or less from the domain of `c`, since that would make the index of the 
    assignment to `v` less than the index of the assignment to `w`, violating the order.
"""
struct Ordered <: AbstractGrammarConstraint
    tree::AbstractRuleNode
    order::Vector{Symbol}
end

function on_new_node(solver::Solver, c::Ordered, path::Vector{Int})
    #minor optimization: prevent the first hardfail (https://github.com/orgs/Herb-AI/projects/6/views/1?pane=issue&itemId=55570518)
    if c.tree isa RuleNode
        @match get_node_at_location(solver, path) begin
            hole::AbstractHole => if !hole.domain[c.tree.ind] return end
            node::RuleNode => if node.ind != c.tree.ind return end
        end
    end
    post!(solver, LocalOrdered(path, c.tree, c.order))
end

"""
    check_tree(c::Ordered, tree::AbstractRuleNode)::Bool

Checks if the given [`AbstractRuleNode`](@ref) tree abides the [`Ordered`](@ref) constraint.
"""
function check_tree(c::Ordered, tree::AbstractRuleNode)::Bool
    vars = Dict{Symbol, AbstractRuleNode}()
    if pattern_match(tree, c.tree, vars) isa PatternMatchSuccess
        # Check variable ordering
        for (var₁, var₂) ∈ zip(c.order[1:end-1], c.order[2:end])
            if vars[var₁] > vars[var₂]
                return false
            end
        end
    end
    return all(check_tree(c, child) for child ∈ tree.children)
end
