"""
	Returns the new index of a grammar rule bsed on the provided `mapping`.
	If `rule` is NOT a key in `mapping`, the original `rule` is returned.
"""
function _get_new_index(rule::Int, mapping::AbstractDict{<:Integer, <:Integer})
    get(mapping, rule, rule)
end # TODO: do we need this function?