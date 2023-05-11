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

function Base.show(io::IO, node::MatchNode; separator=",", last_child::Bool=true)
	print(io, node.rule_ind)
	if !isempty(node.children)
		print(io, "{")
		for (i,c) in enumerate(node.children)
			show(io, c, separator=separator, last_child=(i == length(node.children)))
		end
		print(io, "}")
	elseif !last_child
		print(io, separator)
	end
end

function Base.show(io::IO, node::MatchVar; separator=",", last_child::Bool=true)
	print(io, node.var_name)
	if !last_child
		print(io, separator)
	end
end

contains_var(mv::MatchVar) = true
contains_var(mn::MatchNode) = any(contains_var(c) for c ∈ mn.children)

contains_var(mv::MatchVar, var::Symbol) = mv == var
contains_var(mn::MatchNode, var::Symbol) = any(contains_var(c, var) for c ∈ mn.children)


"""
Converts a matchnode into a Julia expression. 
This is primarily useful for pretty-printing a pattern.
"""
function matchnode2expr(pattern::MatchNode, grammar::Grammar)
	root = deepcopy(grammar.rules[pattern.rule_ind])
	if !grammar.isterminal[pattern.rule_ind] # not terminal
		root,_ = _matchnode2expr(root, pattern, grammar)
	end
	return root
end


function _matchnode2expr(expr::Expr, pattern::MatchNode, grammar::Grammar, j=0)
	for (k,arg) ∈ enumerate(expr.args)
		if isa(arg, Expr)
			expr.args[k],j = _matchnode2expr(arg, pattern, grammar, j)
		elseif haskey(grammar.bytype, arg)
			child = pattern.children[j+=1]
            if child isa MatchNode
			    expr.args[k] = deepcopy(grammar.rules[child.rule_ind])
                if child.children ≠ []
                    expr.args[k],_ = _matchnode2expr(expr.args[k], child, grammar, 0)
                end
            elseif child isa MatchVar
                expr.args[k] = deepcopy(child.var_name)
            end
		end
	end
	return expr, j
end

function _matchnode2expr(expr::Expr, pattern::MatchVar, grammar::Grammar, j=0)
	for (k,arg) ∈ enumerate(expr.args)
		if isa(arg, Expr)
			expr.args[k],j = _matchnode2expr(arg, pattern, grammar, j)
		elseif haskey(grammar.bytype, arg)
			child = pattern.children[j+=1]
			expr.args[k] = deepcopy(grammar.rules[child.ind])
			if !isterminal(grammar, child)
				expr.args[k],_ = _matchnode2expr(expr.args[k], child, grammar, 0)
			end
		end
	end
	return expr, j
end

function _matchnode2expr(typ::Symbol, pattern::MatchVar, grammar::Grammar, j=0)
	return pattern.var_name, j
end

function _matchnode2expr(typ::Symbol, pattern::MatchNode, grammar::Grammar, j=0)
	retval = typ
    if haskey(grammar.bytype, typ)
        child = pattern.children[1]
        if child isa MatchNode
            retval = deepcopy(grammar.rules[child.rule_ind])
            if !grammar.isterminal[child.rule_ind]
                retval,_ = _matchnode2expr(retval, child, grammar, 0)
            end
        elseif child isa MatchVar
            retval = deepcopy(child.var_name)
        end
    end
	return retval, j
end
