
"""
@csgrammar_annotated
Define an annotated grammar and return it as a ContextSensitiveGrammar.
Allows for adding optional annotations per rule.
As well as that, allows for adding optional labels per rule, which can be referenced in annotations. 
Syntax is backwards-compatible with @csgrammar.
Examples:
```julia-repl
g₁ = @csgrammar_annotated begin
    Element = 1
    Element = x
    Element = Element + Element := commutative
    Element = Element * Element := (commutative, transitive)
end
```

```julia-repl
g₁ = @csgrammar_annotated begin
    Element = 1
    Element = x
    Element = Element + Element := forbidden_path([3, 1])
    Element = Element * Element := (commutative, transitive)
end
```

```julia-repl
g₁ = @csgrammar_annotated begin
    one::            Element = 1
    variable::       Element = x
    addition::       Element = Element + Element := (
                                                       commutative,
                                                       transitive,
                                                       forbidden_path([:addition, :one]) || forbidden_path([:one, :variable])
                                                    )
    multiplication:: Element = Element * Element := (commutative, transitive)
end
```
"""
macro csgrammar_annotated(expression)
    # collect and remove labels
    labels = _get_labels!(expression)

    # parse rules, get constraints from annotations
    rules = Any[]
    types = Symbol[]
    bytype = Dict{Symbol,Vector{Int}}()
    constraints = Vector{AbstractConstraint}()

    rule_index = 1

    for (e, label) in zip(expression.args, labels)
        # only consider if e is of type ... = ...
        if !(e isa Expr && e.head == :(=)) continue end
        
        # get the left and right hand side of a rule
        lhs = e.args[1]
        rhs = e.args[2]
        
        # parse annotations if present
        if rhs isa Expr && rhs.head == :(:=)
            # get new annotations as a list
            annotations = rhs.args[2]
            if annotations isa Expr && annotations.head == :tuple
                annotations = annotations.args
            else
                annotations = [annotations]
            end

            # convert annotations, append to constraints
            append!(constraints, annotation2constraint(a, rule_index, labels) for a ∈ annotations)

            # discard annotation
            rhs = rhs.args[1]
        end

        # parse rules
        new_rules = Any[]
        parse_rule!(new_rules, rhs)

        @assert (length(new_rules) == 1 || label == "") "Cannot give rule name $(label) to multiple rules!"

        # add new rules to data
        for new_rule ∈ new_rules
            push!(rules, new_rule)
            push!(types, lhs)
            bytype[lhs] = push!(get(bytype, lhs, Int[]), rule_index)
            
            rule_index += 1
        end
    end

    # determine parameters
    alltypes = collect(keys(bytype))
    is_terminal = [isterminal(rule, alltypes) for rule ∈ rules]
    is_eval = [iseval(rule) for rule ∈ rules]
    childtypes = [get_childtypes(rule, alltypes) for rule ∈ rules]
    bychildtypes = [BitVector([childtypes[i1] == childtypes[i2] for i2 ∈ 1:length(rules)]) for i1 ∈ 1:length(rules)]
    domains = Dict(type => BitArray(r ∈ bytype[type] for r ∈ 1:length(rules)) for type ∈ alltypes)

    return ContextSensitiveGrammar(
        rules,
        types,
        is_terminal,
        is_eval,
        bytype,
        domains,
        childtypes,
        bychildtypes,
        nothing,
        constraints
    )
end


# gets the labels from an expression
function _get_labels!(expression::Expr)::Vector{String}
    labels = Vector{String}()

    for e in expression.args
        # only consider if e is of type ... = ...
        if !(e isa Expr && e.head == :(=)) continue end

        lhs = e.args[1]

        label = ""
        if lhs isa Expr && lhs.head == :(::)
            label = string(lhs.args[1])

            # discard rule name
            e.args[1] = lhs.args[2]
        end

        push!(labels, label)
    end

    # flatten linenums into expression
    Base.remove_linenums!(expression)

    return labels
end


"""
Converts an annotation to a constraint.
commutative: creates an Ordered constraint
transitive: creates an (incorrect) Forbidden constraint
forbidden_path(path::Vector{Union{Symbol, Int}}): creates a ForbiddenPath constraint with the original rule included
... || ...: creates a OneOf constraint (also works with ... || ... || ... et cetera, though not very performant)
"""
function annotation2constraint(annotation::Any, rule_index::Int, labels::Vector{String})::AbstractConstraint
    if annotation isa Expr
        # function-like annotations
        if annotation.head == :call
            func_name = annotation.args[1]
            func_args = annotation.args[2:end]

            if func_name == :forbidden_path
                string_args = eval(func_args[1])
                index_args = [arg isa Symbol ? _get_rule_index(labels, string(arg)) : arg for arg in string_args]

                return ForbiddenPath(
                    [rule_index; index_args]
                )
            end
        end

        # disjunctive annotations
        if annotation.head == :||
            return OneOf(
                @show [annotation2constraint(a, rule_index, labels) for a in annotation.args]
            )
        end
    end

    # commutative annotations
    if annotation == :commutative
        return Ordered(
            MatchNode(rule_index, [MatchVar(:x), MatchVar(:y)]),
            [:x, :y]
        )
    end

    if annotation == :transitive
        return Forbidden(
            MatchNode(rule_index, [MatchVar(:x), MatchNode(rule_index, [MatchVar(:y), MatchVar(:z)])])
        )
    end

    # unknown constraint
    throw(ArgumentError("Annotation $(annotation) at rule $(rule_index) not found!"))
end


# helper function for label lookup
_get_rule_index(labels::Vector{String}, label::String)::Int = findfirst(isequal(label), labels)
