"""
    struct VarNode <: AbstractRuleNode

Matches any subtree and assigns it to a variable name.
The `LocalForbidden` constraint will not match if identical variable symbols match to different trees.
Example usage:

```julia
RuleNode(3, [VarNode(:x), VarNode(:x)])
```

This matches `RuleNode(3, [RuleNode(1), RuleNode(1)])`, `RuleNode(3, [RuleNode(2), RuleNode(2)])`, etc.
but also larger subtrees such as `RuleNode(3, [RuleNode(4, [RuleNode(1)]), RuleNode(4, [RuleNode(1)])])`
"""
struct VarNode <: AbstractRuleNode
    name::Symbol
end

function Base.show(io::IO, node::VarNode; separator=",", last_child::Bool=true)
    print(io, node.name)
    if !last_child
        print(io, separator)
    end
end

HerbCore.isuniform(::VarNode) = false

"""
    contains_varnode(rn::AbstractRuleNode, name::Symbol)

Checks if an [`AbstractRuleNode`](@ref) tree contains a [`VarNode`](@ref) with the given `name`.
"""
contains_varnode(rn::AbstractRuleNode, name::Symbol) = any(contains_varnode(c, name) for c ∈ rn.children)
contains_varnode(vn::VarNode, name::Symbol) = vn.name == name
