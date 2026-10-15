"""
    Forbidden <: AbstractGrammarConstraint

Forbids any subtree that matches the pattern given by `tree` to be generated.
A pattern is a tree of [`AbstractRuleNode`](@ref)s. 

# Example

A node in the tree can be of any type `<:AbstractRuleNode`. For example, a [`RuleNode`](@ref), which contains a rule index corresponding to the 
rule index in the [`AbstractGrammar`](@ref) and the appropriate number of children, or a [`VarNode`](@ref), which contains a single identifier symbol.

Let's consider the tree `1(a, 2(b, 3(c, 4))))`:

- `Forbidden(RuleNode(3, [RuleNode(5), RuleNode(4)]))` forbids `c` to be filled with `5`.
- `Forbidden(RuleNode(3, [VarNode(:v), RuleNode(4)]))` forbids `c` to be filled, since a [`VarNode`] can 
    match any rule, thus making the match attempt successful for the entire domain of `c`. 
    Therefore, this tree invalid.
- `Forbidden(RuleNode(3, [VarNode(:v), VarNode(:v)]))` forbids `c` to be filled with `4`, since that would 
    make both assignments to `v` equal, which causes a successful match.

A [`VarNode`](@ref) can match any subtree, but if there are multiple instances of the same
variable in the pattern, the matched subtrees must be identical.
Any rule in the domain that makes the match attempt successful is removed.

"""
@auto_hash_equals struct Forbidden{R<:AbstractRuleNode} <: AbstractGrammarConstraint
    tree::R
end

local_constraint_types(::Type{<:Forbidden}) = LocalForbidden
function on_new_node(solver::Solver, c::Forbidden, path::Vector{Int})
    #minor optimization: prevent the first hardfail (https://github.com/orgs/Herb-AI/projects/6/views/1?pane=issue&itemId=55570518)
    if c.tree isa RuleNode
        @match get_node_at_location(solver, path) begin
            hole::AbstractHole => if !hole.domain[c.tree.ind]
                return
            end
            node::RuleNode => if node.ind != c.tree.ind
                return
            end
        end
    end
    post!(solver, LocalForbidden(path, c.tree))
end

isantimonotone(::Type{<:Forbidden}) = true

function check_forbidden(forbidden_pattern, cache)
    return t -> check_forbidden(t, forbidden_pattern, nothing, nothing) #objectid(forbidden_pattern), cache)
    # return Base.Fix2(check_forbidden, forbidden_pattern)
end
function check_forbidden(tree, forbidden_pattern, forbidden_pattern_id, cache)
    return !(pattern_match(tree, forbidden_pattern) isa PatternMatchSuccess)
    # return !success_state(get_final_match_result!(tree, forbidden_pattern))
    # return get!(cache, objectid((tree, forbidden_pattern_id))) do
    #     !success_state(get_final_match_result!(tree, forbidden_pattern))
    # end
end

struct StatefulDropWhile{I<:Iterators.Stateful,P<:Function}
    pred::P
    xs::I
end

function Iterators.iterate(ibl::StatefulDropWhile)
    st = ibl.xs
    y = peek(st)
    while !Base.isdone(st)
        if !ibl.pred(y)
            break
        else
            popfirst!(st)
            y = peek(st)
        end
    end
    y
end

Base.IteratorSize(::Type{<:StatefulDropWhile}) = Base.SizeUnknown()
Base.eltype(::Type{StatefulDropWhile{I,P}}) where {I,P} = eltype(I)
Base.IteratorEltype(::Type{StatefulDropWhile{I,P}}) where {I,P} = Base.IteratorEltype(I)

"""
    check_tree(c::Forbidden, tree::AbstractRuleNode)::Bool

Checks if the given [`AbstractRuleNode`](@ref) tree abides the [`Forbidden`](@ref) constraint.
"""
function check_tree(c::Forbidden, tree, cache=nothing)::Bool
    return all(check_forbidden(c.tree, cache), AT.PreOrderDFS(tree))
end

"""
    update_rule_indices!(c::Forbidden, n_rules::Integer)

Updates the `Forbidden` constraint to reflect grammar changes by calling `HerbCore.update_rule_indices!` on its `tree` field.

# Arguments
- `c`: The `Forbidden` constraint to be updated.
- `n_rules`: The new number of rules in the grammar.
"""
function HerbCore.update_rule_indices!(
    c::Forbidden,
    n_rules::Integer,
)
    HerbCore.update_rule_indices!(c.tree, n_rules)
end

"""
    update_rule_indices!(c::Forbidden, grammar::AbstractGrammar)

Updates the `Forbidden` constraint to reflect grammar changes by calling `HerbCore.update_rule_indices!` on its `tree` field.

# Arguments
- `c`: The `Forbidden` constraint to be updated.
- `grammar`: The new number of rules in the grammar.
"""
function HerbCore.update_rule_indices!(
    c::Forbidden,
    grammar::AbstractGrammar,
)
    HerbCore.update_rule_indices!(c.tree, length(grammar.rules))
end

"""
	update_rule_indices!(c::Forbidden, n_rules::Integer, mapping::AbstractDict{<:Integer, <:Integer}, ::Vector{<:AbstractConstraint})

Updates the `Forbidden` constraint to reflect grammar changes by calling `HerbCore.update_rule_indices!` on its `tree` field.

# Arguments
- `c`: The `Forbidden` constraint to be updated
- `n_rules`: The new number of rules in the grammar  
- `mapping`: Dictionary mapping old rule indices to new rule indices
"""
function HerbCore.update_rule_indices!(
    c::Forbidden,
    n_rules::Integer,
    mapping::AbstractDict{<:Integer,<:Integer},
    ::Vector{<:AbstractConstraint}
)
    HerbCore.update_rule_indices!(c.tree, n_rules, mapping)
end

"""
	update_rule_indices!(c::Forbidden, grammar::AbstractGrammar, mapping::AbstractDict{<:Integer, <:Integer})

Updates the `Forbidden` constraint to reflect grammar changes by calling `HerbCore.update_rule_indices!` on its `tree` field.

# Arguments
- `c`: The `Forbidden` constraint to be updated
- `grammar`: The grammar that changed
- `mapping`: Dictionary mapping old rule indices to new rule indices
"""
function HerbCore.update_rule_indices!(
    c::Forbidden,
    grammar::AbstractGrammar,
    mapping::AbstractDict{<:Integer,<:Integer},
)
    HerbCore.update_rule_indices!(c, length(grammar.rules), mapping, grammar.constraints)
end

HerbCore.is_domain_valid(c::Forbidden, n_rules::Integer) = HerbCore.is_domain_valid(c.tree, n_rules)
HerbCore.is_domain_valid(c::Forbidden, grammar::AbstractGrammar) = HerbCore.is_domain_valid(c.tree, length(grammar.rules))

function HerbGrammar.is_constraint_valid(c::Forbidden, grammar::AbstractGrammar; allow_empty_children::Bool)
    return HerbGrammar.is_tree_valid(c.tree, grammar; allow_empty_children=allow_empty_children)
end
