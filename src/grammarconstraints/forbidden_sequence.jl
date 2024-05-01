"""
    ForbiddenPath <: AbstractGrammarConstraint

This [`AbstractGrammarConstraint`] forbids the given `sequence` of rule nodes.
Sequences are strictly vertical and may include gaps. Consider the tree `1(a, 2(b, 3(c, d))))`:
- `[2, 3, d]` is a sequence
- `[1, 3, d]` is a sequence
- `[3, c, d]` is not a sequence

Examples:
- `ForbiddenSequence([3, 4])` enforces that rule `4` cannot be applied at `c` or `d`.
- `ForbiddenSequence([1, 2, 4])` enforces that rule `4` cannot be applied at `b`, `c` or `d`.
- `ForbiddenSequence([1, 4])` enforces that rule `4` cannot be applied anywhere.

If any of the rules in `ignore_if` appears in the sequence, the constraint is ignored.
Suppose the forbidden `sequence = [1, 2, 3]` and `ignore_if = [99]`
Consider the following paths from the root:
- `[1, 2, 2, 3]` is forbidden, as the sequence does not contain `99`
- `[1, 99, 2, 3]` is NOT forbidden, as the sequence does contain `99`
- `[1, 99, 1, 2, 3]` is forbidden, as there is a subsequence that does not contain `99`
"""
struct ForbiddenSequence <: AbstractGrammarConstraint
    sequence::Vector{Int}
    ignore_if::Vector{Int}
end

ForbiddenSequence(sequence::Vector{Int}; ignore_if=Vector{Int}()) = ForbiddenSequence(sequence, ignore_if)

function on_new_node(solver::Solver, c::ForbiddenSequence, path::Vector{Int})
    #minor optimization: prevent the first hardfail (https://github.com/orgs/Herb-AI/projects/6/views/1?pane=issue&itemId=55570518)
    @match get_node_at_location(solver, path) begin
        hole::AbstractHole => if !hole.domain[c.sequence[end]] return end
        node::RuleNode => if node.ind != c.sequence[end] return end
    end
    post!(solver, LocalForbiddenSequence(path, c.sequence, c.ignore_if))
end

"""
    check_tree(c::ForbiddenSequence, tree::AbstractRuleNode; sequence_started=false)::Bool

Checks if the given [`AbstractRuleNode`](@ref) tree abides the [`ForbiddenSequence`](@ref) constraint.
"""
function check_tree(c::ForbiddenSequence, tree::AbstractRuleNode; sequence_started=false)::Bool
    @assert isfilled(tree) "check_tree does not support checking trees that contain holes. $(tree) is a hole."

    # attempt to start the sequence on the any node in the tree
    if !sequence_started
        for child ∈ tree.children
            if !check_tree(c, child, sequence_started=false)
                return false
            end
        end
    end
    
    # add the current node to the current sequence if possible
    if (get_rule(tree) == c.sequence[1])
        remaining_sequence = c.sequence[2:end]
        sequence_started = true
    else
        remaining_sequence = c.sequence
    end

    # the empty sequence is in any tree, so the constraint is violated
    if isempty(remaining_sequence)
        return false
    end
    
    if sequence_started
        # the sequence contains one of the `ignore_if` rules, and therefore is satisfied
        if get_rule(tree) ∈ c.ignore_if
            return true
        end
        
        # continue the current sequence
        smaller_constraint = ForbiddenSequence(remaining_sequence, c.ignore_if)
        for child ∈ tree.children
            if !check_tree(smaller_constraint, child, sequence_started=true)
                return false
            end
        end
    end
    return true
end
