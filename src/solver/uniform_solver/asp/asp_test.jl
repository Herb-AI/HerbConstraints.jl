using HerbCore, HerbGrammar, HerbConstraints, Clingo_jll

#include("parsing_IO.jl")

g = @csgrammar begin
    Number = |(1:2)
    Number = x
    Number = Number + Number
    Number = Number * Number
end

addconstraint!(g, Forbidden(RuleNode(5, [RuleNode(3), RuleNode(3)])))
addconstraint!(g, Forbidden(RuleNode(5, [UniformHole(BitVector((1, 1, 1, 0, 0)), []), UniformHole(BitVector((1, 1, 0, 0, 0)), [])])))
addconstraint!(g, Forbidden(RuleNode(5, [RuleNode(4, [RuleNode(1), RuleNode(2)]), RuleNode(3)])))

addconstraint!(g, Contains(4))
addconstraint!(g, ContainsSubtree(RuleNode(4, [UniformHole(BitVector((1, 1, 0, 0, 0)), []), RuleNode(3)])))

addconstraint!(g, Unique(5))

addconstraint!(g, Ordered(RuleNode(5, [VarNode(:X), VarNode(:Y)]), [:X, :Y]))

# addconstraint!(g, ForbiddenSequence(Vector{Int}([5, 4, 3])))
# addconstraint!(g, ForbiddenSequence(Vector{Int}([5, 1])))


#t1 = RuleNode(4, [RuleNode(1), RuleNode(2)])
#t2 = DomainRuleNode(BitVector((0, 0, 0, 1, 1)), [RuleNode(1), RuleNode(2)])
#t3 = UniformHole(BitVector((0, 0, 0, 1, 1)), [UniformHole(BitVector((1, 1, 1, 0, 0)), []), UniformHole(BitVector((1, 1, 1, 0, 0)), [])])
t4 = UniformHole(BitVector((0, 0, 0, 1, 1)), [UniformHole(BitVector((0, 0, 0, 1, 1)), [UniformHole(BitVector((1, 1, 1, 0, 0)), []), UniformHole(BitVector((1, 1, 1, 0, 0)), [])]), UniformHole(BitVector((1, 1, 1, 0, 0)), [])])

sm = HerbConstraints.StateManager()
t4_right = HerbConstraints.StateHole(sm, t4)

include("asp_tree_transformations.jl")

include("asp_constraint_transformations.jl")

include("asp_uniform_tree_solver.jl")

asp = ASPSolver(g, t4_right)

solve(asp, true)

println("Found $(length(asp.solutions)) solutions:")
for sol in asp.solutions
    println("   ", sol)
end


# function tree_to_ASP(tree::AbstractRuleNode, grammar::AbstractGrammar, node_index::Int64)
#     output = ""
#     output *= node_to_ASP(tree, grammar, node_index)
#     parent_index = node_index
#     node_index = node_index + 1
#     for (child_ind, child) in enumerate(tree.children)
#         output *= "child($(parent_index),$(child_ind),$(node_index)).\n"
#         ch_output, node_index = tree_to_ASP(child, grammar, node_index)
#         output *= ch_output
#     end
#     return output, node_index
# end

# function node_to_ASP(tree::RuleNode, grammar::AbstractGrammar, node_index::Int64)
#     return "node($(node_index),$(get_rule(tree))).\n"
# end

# function node_to_ASP(tree::Union{UniformHole,DomainRuleNode}, grammar::AbstractGrammar, node_index::Int64)
#     options = join(["node($(node_index),$(ind))" for ind in filter(x -> tree.domain[x], 1:length(grammar.rules))], ";")
#     return "1 { $(options) } 1.\n"
# end


# function to_ASP(grammar::AbstractGrammar)
#     output = ""
#     for (const_ind, constraint) in enumerate(grammar.constraints)
#         output *= to_ASP(grammar, constraint, const_ind)
#         output *= "\n"
#     end
#     return output
# end

# function forbidden_tree_to_ASP(grammar::AbstractGrammar, tree::AbstractRuleNode, node_index::Int64, constraint_index::Int64)
#     tree_facts, additional_facts = "", ""
#     tmp_facts, tmp_additional = forbidden_node_to_ASP(grammar, tree, node_index, constraint_index)
#     tree_facts *= tmp_facts
#     additional_facts *= join(tmp_additional, "")
#     parent_index = node_index
#     node_index += 1

#     for (child_ind, child) in enumerate(tree.children)
#         if isa(child, VarNode)
#             tree_facts *= ",child(X$(parent_index),$(child_ind),$(child.name))"
#         else
#             tmp_facts, tmp_additional, node_index = forbidden_tree_to_ASP(grammar, child, node_index, constraint_index)
#             tree_facts *= ",child(X$(parent_index),$(child_ind),X$(node_index))"
#             tree_facts *= ",$(tmp_facts)"
#             additional_facts *= join(tmp_additional, "")
#             node_index += 1
#         end
#     end

#     return tree_facts, additional_facts, node_index
# end

# function forbidden_node_to_ASP(grammar::AbstractGrammar, node::RuleNode, node_index::Int64, constraint_index::Int64)
#     return "node(X$(node_index),$(get_rule(node)))", []
# end

# function forbidden_node_to_ASP(grammar::AbstractGrammar, node::Union{UniformHole,DomainRuleNode}, node_index::Int64, constraint_index::Int64)
#     return "node(X$(node_index),D$(node_index)),allowed(x$(node_index),D$(node_index))", map(x -> "allowed(c$(constraint_index)x$(node_index), $x).\n", collect(filter(x -> node.domain[x], 1:length(grammar.rules))))
# end


# function to_ASP(grammar::AbstractGrammar, constraint::Forbidden, index::Int64)
#     tree_facts, domains, _ = forbidden_tree_to_ASP(grammar, constraint.tree, 1, index)

#     output = domains

#     output *= ":- $(tree_facts).\n"
#     return output
# end

# function to_ASP(grammar::AbstractGrammar, constraint::Contains, index::Int64)
#     return ":- not node(_, $(constraint.rule)).\n"
# end


# function to_ASP(grammar::AbstractGrammar, constraint::Unique, index::Int64)
#     return "{ X : node(X, $(constraint.rule)) } 1.\n"
# end



# function to_ASP(grammar::AbstractGrammar, constraint::ContainsSubtree, index::Int64)
#     tree, domains, _ = forbidden_tree_to_ASP(grammar, constraint.tree, 1, index)
#     output = ""
#     output *= domains

#     output *= "subtree(c$(index)) :- $(tree).\n:- not subtree(c$(index)).\n"

#     return output
# end



# # function parse_constraint(grammar::AbstractGrammar, constraint::Ordered, index::Int64)
# #     tree, domains, _ = parse_tree_var(constraint.tree, grammar, Vector{AbstractString}(), Vector{AbstractString}(), 1)

# # end

# function to_ASP(grammar::AbstractGrammar, constraint::Ordered, index::Int64)
#     output = "is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV < YV.\n"
#     output *= "is_smaller(X,Y) :- node(X,XV), node(Y,YV), XV = YV, S = #sum {Z: child(X,Z,XC), child(Y,Z,YC), is_smaller(XC, YC)}, M = #max {Z: child(X,Z,XC)}, S = M.\n"

#     tree, domains, _ = forbidden_tree_to_ASP(grammar, constraint.tree, 1, index)

#     output *= domains

#     # create ordered constraints, for each consecutive pair of ordered vars
#     for i in 1:length(constraint.order)-1
#         output *= ":- $(tree), not is_smaller($(constraint.order[i]), $(constraint.order[i+1])).\n"
#     end

#     return output
# end


# function solve_uniform_tree(tree::AbstractRuleNode, grammar::AbstractGrammar)
#     println("%%% Tree")
#     string_tree, _ = tree_to_ASP(tree, grammar, 1)
#     println(string_tree)
#     println("%%% Constraint")
#     constraints = to_ASP(grammar)
#     println(constraints)
# end

# solve_uniform_tree(t1, g)
# solve_uniform_tree(t2, g)
# solve_uniform_tree(t3, g)
# solve_uniform_tree(t4, g)
