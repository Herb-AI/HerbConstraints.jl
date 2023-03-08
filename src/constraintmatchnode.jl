"""
Tree structure to which rulenode trees can be matched.
"""
abstract type AbstractConstraintMatchNode end

struct ConstraintMatchNode <: AbstractConstraintMatchNode
    rule_ind::Int
    children::Vector{AbstractConstraintMatchNode}
end

ConstraintMatchNode(rule_ind::Int) = ConstraintMatchNode(rule_ind, [])

struct ConstraintMatchVar <: AbstractConstraintMatchNode
    var_name::Symbol
end
