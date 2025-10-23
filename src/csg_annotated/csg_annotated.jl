
"""
@csgrammar_annotated
Define an annotated grammar and return it as a ContextSensitiveGrammar.
Allows for adding optional annotations per rule.
As well as that, allows for adding optional labels per rule, which can be referenced in annotations. 
Syntax is backwards-compatible with @csgrammar.Converts an annotation to constraints.

Supported annotations:
- commutative: creates an Ordered constraint on the (two) children of the rule
- associative: creates Forbidden constraints, such that rule can only be applied in a path formation (no sub trees of the rule r{r,r} allowed)
- identity(label): creates Forbidden constraints for applying the rule on an identity element from the specified domain
- inverse(label1): creates Forbidden constraints for applying the rule on an an element and its inverse from the specified domain (assumes inverses a single child)
- distributive_over(label): creates Forbidden constraints for applying the specified domain on (two) children of the rule with a common child (in same position, unless commutative)

Examples:

```julia-repl
g₁ = @csgrammar_annotated begin
    Element = 1
    Element = x
    Element = Element + Element := commutative
    Element = Element * Element := (commutative, associativity)
end
```

```julia-repl
g₁ = @csgrammar_annotated begin
    zero::           Element = 0
    one::            Element = 1
    variable::       Element = x
    addition::       Element = Element + Element := (
                                                       commutative,
                                                       associativity,
                                                       identity("zero"),
                                                    )
    multiplication:: Element = Element * Element := (commutative, associativity, identity("one"), distributive_over("addition"))
end
```
"""
function csgrammar_annotated(expression)
    grammar, bylabel, rule_annotations = _process_expression(expression)

    labels = Dict(label => BitArray(r ∈ bylabel[label] for r ∈ 1:length(grammar.rules)) for label ∈ keys(bylabel) if label != "")

    annotated_grammar = AnnotatedGrammar(grammar, labels, rule_annotations)
    for rule_index in keys(rule_annotations)
        for annotation in rule_annotations[rule_index]
            _annotation2constraints!(annotated_grammar, rule_index, annotation)
        end
    end

    return annotated_grammar
end

"""    
    @csgrammar_annotated ex
A macro wrapper for the `csgrammar_annotated` function.
"""
macro csgrammar_annotated(ex)
    return :(csgrammar_annotated($(QuoteNode(ex))))
end

"""
    expr2csgrammar(ex::Expr)::AnnotatedGrammar  
A function for converting an `Expr` to a [`AnnotatedGrammar`](@ref).
If the expression is hardcoded, you should use the [`@csgrammar_annotated`](@ref) macro.
Only expressions in the correct format (see [`csgrammar_annotated`](@ref)) can be converted.
"""
function expr2csgrammar_annotated(ex::Expr)::AnnotatedGrammar
    return csgrammar_annotated(ex)
end

"""
   AnnotatedGrammar
A struct for holding an annotated context-sensitive grammar.
Fields:
- grammar: The underlying ContextSensitiveGrammar
- label_domains: A dictionary mapping labels to their corresponding domain BitVectors
- rule_annotations: A dictionary mapping rule indices to their corresponding annotations
"""
struct AnnotatedGrammar
   grammar::ContextSensitiveGrammar
   label_domains::Dict{String, BitArray}
   rule_annotations::Dict{Int,Vector{Any}}
end

function _process_expression(expression)::Tuple{
        ContextSensitiveGrammar, 
        Dict{String,Vector{Int}},
        Dict{Int,Vector{Any}},
        }
    grammar = ContextSensitiveGrammar()
    bylabel = Dict{String,Vector{Int}}()
    rule_annotations = Dict{Int,Vector{Any}}()
    for e in expression.args
        if !(e isa Expr && e.head == :(=))
            continue
        end
        if !(e.head == :(=))
            error("Expected rule definition of the form lhs = rhs, got: $e (rule $(length(grammar.rules)+1))")
        end

        label = _get_label!(e)
        annotations = _get_annotations!(e)

        numrules_before = length(grammar.rules)
        add_rule!(grammar, e)
        numrules_after = length(grammar.rules)

        bylabel[label] = numrules_before+1:numrules_after

        for rule in bylabel[label]
            rule_annotations[rule] = annotations
        end
    end
    return grammar, bylabel, rule_annotations
end

# gets the label from an expression
function _get_label!(e)::String
    # get the left hand side of a rule
    lhs = e.args[1]
    label = ""
    # parse label if present, i.e., of the form label::rule_lhs
    if lhs isa Expr && lhs.head == :(::)
        label = string(lhs.args[1])

        # discard rule name
        e.args[1] = lhs.args[2]
    end
    return label
end

# gets the annotation from an expression
function _get_annotations!(e)::Vector{Any}
    # get the right hand side of a rule
    rhs = e.args[2]
    annotations = Expr[]
    # parse annotations if present, i.e., of the form rule_rhs := annotations
    if rhs isa Expr && rhs.head == :(:=)
        annotations = rhs.args[2]
        if annotations isa Expr && annotations.head == :tuple
            annotations = annotations.args
        else
            annotations = [annotations]
        end

        # discard rule name
        e.args[2] = rhs.args[1]
    end
    return annotations
end

function _annotation2constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
    annotation::Any,
)
    if annotation isa Expr && annotation.head == :call
        annotation_name = annotation.args[1]
        labels_domain = annotated_grammar.label_domains[String(annotation.args[2])]
        if annotation_name == :identity
            _identity_constraints!(annotated_grammar, rule_index, labels_domain)
        elseif annotation_name == :inverse
            _inverse_constraints!(annotated_grammar, rule_index, labels_domain)
        elseif annotation_name == :distributive_over
            _distributive_over_constraints!(annotated_grammar, rule_index, labels_domain)
        else
            throw(ArgumentError("Annotation call $(annotation) not found! (rule $(rule_index))")) 
        end
    elseif annotation == :commutative
        _commutative_constraints!(annotated_grammar, rule_index)
    elseif annotation == :associative
        _associativity_constraints!(annotated_grammar, rule_index)
    else
        throw(ArgumentError("Annotation $(annotation) not found! (rule $(rule_index))"))
    end
end


function _identity_constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
    labels_domain::BitVector,
)
    #check number of children of the rule
    children = length(annotated_grammar.grammar.childtypes[rule_index])
    #create a list with 'children' number of VarNodes (automated for any number of children)

    var_nodes = [VarNode(Symbol("child_$(i)")) for i in 1:children-1]
    for i in 1:children
        #create a copy of the var_nodes list
        nodes = Vector{Any}(copy(var_nodes))
        #insert the DomainRuleNode at position i
        insert!(nodes, i, DomainRuleNode(labels_domain))
        #add the Forbidden constraint
        addconstraint!(annotated_grammar.grammar,
            Forbidden(RuleNode(rule_index, nodes))
        )
    end
end

function _inverse_constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
    labels_domain::BitVector,
)
    addconstraint!(annotated_grammar.grammar,
        Forbidden(RuleNode(rule_index, [DomainRuleNode(labels_domain, [VarNode(:x)]), VarNode(:a)]))
    )
    addconstraint!(annotated_grammar.grammar,
        Forbidden(RuleNode(rule_index, [VarNode(:a), DomainRuleNode(labels_domain, [VarNode(:x)])]))
    )
end

function _distributive_over_constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
    labels_domain::BitVector,
)
    rulenode_ax = RuleNode(rule_index, [VarNode(:a), VarNode(:x)])
    rulenode_bx = RuleNode(rule_index, [VarNode(:b), VarNode(:x)])
    rulenode_xa = RuleNode(rule_index, [VarNode(:x), VarNode(:a)])
    rulenode_xb = RuleNode(rule_index, [VarNode(:x), VarNode(:b)])

    addconstraint!(annotated_grammar.grammar,
        Forbidden(DomainRuleNode(labels_domain, [rulenode_ax, rulenode_bx]))
    )
    addconstraint!(annotated_grammar.grammar,
        Forbidden(DomainRuleNode(labels_domain, [rulenode_xa, rulenode_xb]))
    )
    if :commutative ∈ annotated_grammar.rule_annotations[rule_index]
        addconstraint!(annotated_grammar.grammar,
            Forbidden(DomainRuleNode(labels_domain, [rulenode_xa, rulenode_xb]))
        )
        addconstraint!(annotated_grammar.grammar,
            Forbidden(DomainRuleNode(labels_domain, [rulenode_ax, rulenode_bx]))
        )
    end
end

function _commutative_constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
)
     addconstraint!(annotated_grammar.grammar,
                Ordered(
                RuleNode(rule_index, [VarNode(:x), VarNode(:y)]),
                [:x, :y],
                )
            ) 
end

function _associativity_constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
)
    addconstraint!(annotated_grammar.grammar, Forbidden(RuleNode(rule_index, [
                                RuleNode(rule_index, [VarNode(:a), VarNode(:b)]),
                                RuleNode(rule_index, [VarNode(:c), VarNode(:d)])
                            ])))
    if :commutative ∈ annotated_grammar.rule_annotations[rule_index]
        child = RuleNode(rule_index, [VarNode(:y), VarNode(:a)])
        addconstraint!(annotated_grammar.grammar, Ordered(
                    RuleNode(rule_index, [VarNode(:x), child]),
                    [:x, :y],
                ))
        addconstraint!(annotated_grammar.grammar, Ordered(
                    RuleNode(rule_index, [child, VarNode(:x)]),
                    [:x, :y],
                ))
    end
end
