using HerbCore, HerbGrammar, HerbConstraints, Clingo_jll
include("parsing_IO.jl")

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

addconstraint!(g, ForbiddenSequence(Vector{Int}([5,4,3])))
addconstraint!(g, ForbiddenSequence(Vector{Int}([5,1])))


t1 = RuleNode(4, [RuleNode(1), RuleNode(2)])
t2 = DomainRuleNode(BitVector((0, 0, 0, 1, 1)), [RuleNode(1), RuleNode(2)])
t3 = UniformHole(BitVector((0, 0, 0, 1, 1)), [UniformHole(BitVector((1, 1, 1, 0, 0)), []), UniformHole(BitVector((1, 1, 1, 0, 0)), [])])
t4 = UniformHole(BitVector((0, 0, 0, 1, 1)), [UniformHole(BitVector((0,0,0,1,1)), [UniformHole(BitVector((1, 1, 1, 0, 0)), []), UniformHole(BitVector((1, 1, 1, 0, 0)), [])]), UniformHole(BitVector((1,1,1,0,0)), [])])


function parse_tree(tree::AbstractRuleNode, grammar::AbstractGrammar, output::AbstractString, node_index::Int64)
    if tree isa RuleNode
        output *= "node($(node_index),$(tree.ind)).\n"
    elseif tree isa UniformHole || tree isa DomainRuleNode
        options = join(["node($(node_index),$(ind))" for ind in filter(x -> tree.domain[x], 1:length(grammar.rules))], ";")
        output *= "1 { $(options) } 1.\n"
    end
    parent_idx = node_index
    node_index += 1
    for (child_idx, child) in enumerate(tree.children)
        output *= "child($(parent_idx),$(child_idx),$(node_index)).\n"
        output, node_index = parse_tree(child, grammar, output, node_index)
    end
    return output, node_index
end

function parse_tree_var(tree::AbstractRuleNode, grammar::AbstractGrammar, output::Vector{AbstractString}, domains::Vector{AbstractString}, node_index::Int64)
    parent = "X$(node_index)"
    if tree isa RuleNode
        push!(output, "node($(parent),$(tree.ind))")
    elseif tree isa UniformHole || tree isa DomainRuleNode
        push!(output, "node($(parent),$(parent)D), allowed(x$(node_index)d,$(parent)D)")
        for ind in filter(x -> tree.domain[x], 1:length(grammar.rules))
            push!(domains, "allowed(x$(node_index)d,$(ind))")
        end
    end
    node_index += 1
    for (child_idx, child) in enumerate(tree.children)
        push!(output, "child($(parent),$(child_idx),X$(node_index))")
        output, domains, node_index = parse_tree_var(child, grammar, output, domains, node_index)
    end
    return output, domains, node_index
end

function parse_constraints(grammar::AbstractGrammar)
    output = ""
    for (index, constraint) in enumerate(grammar.constraints)
        output *= parse_constraint(grammar, constraint, index)
    end
    return output
end

function parse_constraint(grammar::AbstractGrammar, constraint::Forbidden, index::Int64)
    tree, domains, _ = parse_tree_var(constraint.tree, grammar, Vector{AbstractString}(), Vector{AbstractString}(), 1)

    # % :- node(X,5), child(X,1,Y), node(Y,YD), allowed(yD,YD).
    # % allowed(yD,3).
    # % allowed(yD,2).
    # % allowed(yD,1).    
    output = ":- $(join(tree, ", ")).\n"
    for d in domains
        output *= "$(d).\n"
    end
    return output
end

function parse_constraint(grammar::AbstractGrammar, constraint::Contains, index::Int64)
    return ":- not node(_,$(constraint.rule)).\n"
end

function parse_constraint(grammar::AbstractGrammar, constraint::Unique, index::Int64)
    return "{ X : node(X,$(constraint.rule)) } 1."
end

function parse_constraint(grammar::AbstractGrammar, constraint::ContainsSubtree, index::Int64)
    tree, domains, _ = parse_tree_var(constraint.tree, grammar, Vector{AbstractString}(), Vector{AbstractString}(), 1)
    output = "subtree(c$(index)) :- $(join(tree, ", ")).\n:- not subtree(c$(index)).\n"
    for d in domains
        output *= "$(d).\n"
    end
    return output    
end

function parse_constraint(grammar::AbstractGrammar, constraint::ForbiddenSequence, index::Int64)
    ## TODO implement
end

function parse_constraint(grammar::AbstractGrammar, constraint::Ordered, index::Int64)
    tree, domains, _ = parse_tree_var(constraint.tree, grammar, Vector{AbstractString}(), Vector{AbstractString}(), 1)

end


function solve_uniform_tree(tree::AbstractRuleNode, grammar::AbstractGrammar)
    println("%%% Tree")
    string_tree, _ = parse_tree(tree, grammar, "", 1)
    println(string_tree)
    println("%%% Constraint")
    constraints = parse_constraints(grammar)
    println(constraints)
end

solve_uniform_tree(t1,g)
solve_uniform_tree(t2,g)
solve_uniform_tree(t3,g)
solve_uniform_tree(t4,g)
