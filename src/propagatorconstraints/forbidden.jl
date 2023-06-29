"""
    Forbidden <: PropagatorConstraint

This [`PropagatorConstraint`] forbids any subtree that matches the pattern given by `tree` to be generated.
A pattern is a tree of [`AbstractMatchNode`](@ref)s. 
Such a node can either be a [`MatchNode`](@ref), which contains a rule index corresponding to the 
rule index in the [`Grammar`](@ref) and the appropriate number of children, similar to [`RuleNode`](@ref)s.
It can also contain a [`MatchVar`](@ref), which contains a single identifier symbol.
A [`MatchVar`](@ref) can match any subtree, but if there are multiple instances of the same
variable in the pattern, the matched subtrees must be identical.
Any rule in the domain that makes the match attempt successful is removed.

For example, consider the tree `1(a, 2(b, 3(c, 4))))`:

- `Forbidden(MatchNode(3, [MatchNode(5), MatchNode(4)]))` forbids `c` to be filled with `5`.
- `Forbidden(MatchNode(3, [MatchVar(:v), MatchNode(4)]))` forbids `c` to be filled, since a [`MatchVar`] can 
  match any rule, thus making the match attempt successful for the entire domain of `c`. 
  Therefore, this tree invalid.
- `Forbidden(MatchNode(3, [MatchVar(:v), MatchVar(:v)]))` forbids `c` to be filled with `4`, since that would 
  make both assignments to `v` equal, which causes a successful match.

!!! warning
    The [`Forbidden`](@ref) constraint makes use of [`LocalConstraint`](@ref)s to make sure that constraints 
    are also enforced in the future when the context of a [`Hole`](@ref) changes. 
    Therefore, [`Forbidden`](@ref) can only be used in implementations that keep track of the 
    [`LocalConstraint`](@ref)s and propagate them at the right moments.
"""
struct Forbidden <: PropagatorConstraint
	tree::AbstractMatchNode
end


"""
    propagate(c::Forbidden, g::Grammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}

Propagates the [`Forbidden`](@ref) constraint.
It removes the rules from the `domain` that would complete the forbidden tree.

!!! warning
    The [`Forbidden`](@ref) constraint makes use of [`LocalConstraint`](@ref)s to make sure that constraints 
    are also enforced in the future when the context of a [`Hole`](@ref) changes. 
    Therefore, [`Forbidden`](@ref) can only be used in implementations that keep track of the 
    [`LocalConstraint`](@ref)s and propagate them at the right moments.
"""
function propagate(c::Forbidden, g::Grammar, context::GrammarContext, domain::Vector{Int})::Tuple{Vector{Int}, Vector{LocalConstraint}}
    notequals_constraint = LocalForbidden(context.nodeLocation, c.tree)
    new_domain, new_constraints = propagate(notequals_constraint, g, context, domain)
    return new_domain, new_constraints
end

"""
    check_tree(c::Forbidden, g::Grammar, tree::RuleNode)::Bool

Checks if the given [`AbstractRuleNode`](@ref) tree abides the [`Forbidden`](@ref) constraint.
"""
function check_tree(c::Forbidden, g::Grammar, tree::RuleNode)::Bool
    vars = Dict{Symbol, AbstractRuleNode}()
    if _pattern_match(tree, c.tree, vars) ≡ nothing
        return false
    end
    return all(check_tree(c, g, child) for child ∈ tree.children)
end

function check_tree(c::Forbidden, ::Grammar, tree::Hole)::Bool
    vars = Dict{Symbol, AbstractRuleNode}()
    return _pattern_match(tree, c.tree, vars) !== nothing
end