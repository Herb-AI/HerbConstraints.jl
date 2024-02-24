using HerbCore
using HerbGrammar

"""
    Solver

Maintains a feasible partial program in a [`State`](@ref). A [`ProgramIterator`](@ref) may manipulate the partial tree with the following functions:
- `remove`
- `substitute`
- `fill`
"""
mutable struct Solver
    grammar::Grammar
    #stats?
end

#TODO: remove stub
function get_tree(solver::Solver)::AbstractRuleNode
    return Hole(BitVector((0)));
end

#TODO: try to reduce to FixedShapedHole or RuleNode
function remove!(solver::Solver, hole::Hole, rule_index::Int)
    hole.domain[rule_index] = false
end

#TODO: try to reduce to FixedShapedHole or RuleNode
function remove!(solver::Solver, hole::Hole, rules::BitVector)
    hole.domain .-= rules
end

#TODO: implement
function fill!(solver::Solver, hole::Hole, rule_index::Int)
    throw("NotImplementedException")
end

#TODO: try to reduce to FixedShapedHole or RuleNode
function remove_all_but!(solver::Solver, hole::Hole, rules::BitVector)
    @assert is_subdomain(rules, hole.domain) "The remaining rules are required to be a subdomain of the hole to remove from"
    hole.domain = rules
end

"""
Takes a [VariableShapedHole](@ref) and tries to reduce it to a [FixedShapedHole](@ref)
"""
function make_fixed_shaped(solver::Solver, hole::VariableShapedHole)::AbstractRuleNode
    if is_subdomain(hole.domain, grammar.bychildtypes[findfirst(hole.domain)])
        #TODO: instantiate new holes underneath the FixedShapedHole
        hole = FixedShapedHole(hole.domain, [])
        # for child ∈ node.children
        #     #todo: notify the solver about the new nodes
        # end
        return hole
    end
    return hole
end

"""
Checks if `subdomain` is a subdomain of `domain`.

Example: [0, 0, 1, 0] is a subdomain of [0, 1, 1, 1]
"""
function is_subdomain(subdomain::BitVector, domain::BitVector)
    return all(.!subdomain .| domain)
end


# function expand(hole::VariableShapedHole, grammar::ContextSensitiveGrammar)
    # while true
    #     rule = findfirst(hole.domain)
    #     if isnothing(rule)
    #         break
    #     end
    #     fixed_shaped_domain = grammar.bychildtypes[rule] .& hole.domain
    #     remove!(solver, hole, fixed_shaped_domain)
    #     remove_all_but!(solver, hole, fixed_shaped_domain)
    # end
# end

# function expand(hole::VariableShapedHole, grammar::ContextSensitiveGrammar)
#     hole
# end

# function _expand(
#     node::Hole, 
#     grammar::ContextSensitiveGrammar, 
#     ::Int, 
#     max_holes::Int,
#     context::GrammarContext,
#     iter::TopDownIterator
# )::Union{ExpandFailureReason, Vector{TreeConstraints}}
#     nodes::Vector{TreeConstraints} = []
    
#     new_nodes = map(i -> RuleNode(i, grammar), findall(node.domain))
#     for new_node ∈ derivation_heuristic(iter, new_nodes, context)

#         # If dealing with the root of the tree, propagate here
#         if context.nodeLocation == []
#             propagate_result, new_local_constraints = propagate_constraints(new_node, grammar, context.constraints, max_holes, HoleReference(node, []))
#             if propagate_result == tree_infeasible continue end
#             push!(nodes, (new_node, new_local_constraints, propagate_result))
#         else
#             push!(nodes, (new_node, context.constraints, tree_incomplete))
#         end

#     end


#     return nodes
# end

# function remove_rule!(s::Solver, hole::Hole, rule::Int)
#     hole.domain[rule] = 0
#     remaining_rule = findfirst(isequal(domain), 1) 
#     if all(isless, b, a)
    
# end


# fill!(s::Solver, hole::Hole, rule::Int)
