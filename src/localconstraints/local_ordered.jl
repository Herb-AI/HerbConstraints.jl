"""
Enforces an order over two or more subtrees that fill the variables 
specified in `order` when the pattern is applied at the location given by `path`.
Use an `Ordered` constraint for enforcing this throughout the entire search space.
"""
mutable struct LocalOrdered <: LocalConstraint
    path::Vector{Int}
    tree::AbstractRuleNode
    order::Vector{Symbol}
end
