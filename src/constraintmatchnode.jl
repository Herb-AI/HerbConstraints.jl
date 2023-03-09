"""
Tree structure to which rulenode trees can be matched.
Consists of ConstraintMatchNodes, which can match a specific RuleNode,
and ConstraintMatchVars, which is a variable that can be filled in with any RuleNode.
"""
abstract type AbstractConstraintMatchNode end

"""
Match a specific rulenode, where the grammar rule index is `rule_ind` 
and `children` matches the children of the RuleNode.
Example usage:

    ConstraintMatchNode(3, [ConstraintMatchNode(1), ConstraintMatchNode(2)])

This matches `RuleNode(3, [RuleNode(1), RuleNode(2)])`
"""
struct ConstraintMatchNode <: AbstractConstraintMatchNode
    rule_ind::Int
    children::Vector{AbstractConstraintMatchNode}
end

ConstraintMatchNode(rule_ind::Int) = ConstraintMatchNode(rule_ind, [])

"""
Matches anything and assigns it to a variable. 
The `ForbiddenTree` constraint will not match if identical variable symbols match to different trees.
Example usage:

    ConstraintMatchNode(3, [ConstraintMatchVar(:x), ConstraintMatchVar(:x)])

This matches `RuleNode(3, [RuleNode(1), RuleNode(1)])`, `RuleNode(3, [RuleNode(2), RuleNode(2)])`, etc.
"""
struct ConstraintMatchVar <: AbstractConstraintMatchNode
    var_name::Symbol
end
