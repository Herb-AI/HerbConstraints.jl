"""
Tree structure to which rulenode trees can be matched.
Consists of MatchNodes, which can match a specific RuleNode,
and MatchVars, which is a variable that can be filled in with any RuleNode.
"""
abstract type AbstractMatchNode end

"""
Match a specific rulenode, where the grammar rule index is `rule_ind` 
and `children` matches the children of the RuleNode.
Example usage:

    MatchNode(3, [MatchNode(1), MatchNode(2)])

This matches `RuleNode(3, [RuleNode(1), RuleNode(2)])`
"""
struct MatchNode <: AbstractMatchNode
    rule_ind::Int
    children::Vector{AbstractMatchNode}
end

MatchNode(rule_ind::Int) = MatchNode(rule_ind, [])

"""
Matches anything and assigns it to a variable. 
The `ForbiddenTree` constraint will not match if identical variable symbols match to different trees.
Example usage:

    MatchNode(3, [MatchVar(:x), MatchVar(:x)])

This matches `RuleNode(3, [RuleNode(1), RuleNode(1)])`, `RuleNode(3, [RuleNode(2), RuleNode(2)])`, etc.
"""
struct MatchVar <: AbstractMatchNode
    var_name::Symbol
end

