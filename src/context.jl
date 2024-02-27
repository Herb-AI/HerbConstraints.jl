"""
    mutable struct GrammarContext

Structure used to track the context.
Contains:
	- the expression being modified 
	- the path to the hole that is being expanded, represented as a sequence of child indices.
	  e.g., [2, 1] would point to the first child of the second child of the root.
	- a vector with local constraints that should be propagated upon expansion.
"""
mutable struct GrammarContext
	originalExpr::AbstractRuleNode			# original expression being modified
	nodeLocation::Vector{Int}   			# path to the current node in the expression, 
	constraints::Set{LocalConstraint}		# local constraints that should be propagated
end

GrammarContext(originalExpr::AbstractRuleNode) = GrammarContext(originalExpr, [], [])

"""
    addparent!(context::GrammarContext, parent::Int)

Adds a parent to the context.
The parent is defined by the grammar rule id.
"""
function addparent!(context::GrammarContext, parent::Int)
	push!(context.nodeLocation, parent)
end


"""
    copy_and_insert(old_context::GrammarContext, parent::Int)

Copies the given context and insert the parent in the node location.
"""
function copy_and_insert(old_context::GrammarContext, parent::Int)
	new_context = GrammarContext(old_context.originalExpr, deepcopy(old_context.nodeLocation), deepcopy(old_context.constraints))
	push!(new_context.nodeLocation, parent)
	new_context
end
