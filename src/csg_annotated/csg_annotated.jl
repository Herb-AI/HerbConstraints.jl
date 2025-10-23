
"""
@csgrammar_annotated
Define an annotated grammar and return it as a ContextSensitiveGrammar.
Allows for adding optional annotations per rule.
As well as that, allows for adding optional labels per rule, which can be referenced in annotations. 
Syntax is backwards-compatible with @csgrammar.Converts an annotation to constraints.

Supported annotations:
- commutative: creates an Ordered constraint on the (two) children of the rule
- associativity: creates Forbidden constraints, such that rule can only be applied in a path formation (no sub trees of the rule r{r,r} allowed)
- identity(label1, label2, ...): creates Forbidden constraints for applying the rule on an identity element from the specified domain
- inverse(label1, label2, ...): creates Forbidden constraints for applying the rule on an an element and its inverse from the specified domain (assumes inverses a single child)
- distributive_over(label1, label2, ...): creates Forbidden constraints for applying the specified domain on (two) children of the rule with a common child (in same position, unless commutative)

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
function csgrammar_annotated(expression::Expr)::AnnotatedGrammar
    grammar, bylabel, rule_annotations = _process_expression(expression)

    labels = Dict(label => BitArray(r ∈ bylabel[label] for r ∈ 1:length(grammar.rules)) for label ∈ keys(bylabel) if label != "")

    annotated_grammar = AnnotatedGrammar(grammar, labels, rule_annotations)
    for (rule_index, annotation) in rule_annotations
        _annotation2constraints!(annotated_grammar, rule_index, annotation)
    end

    return annotated_grammar
end

macro csgrammar_annotated(ex::Expr)
    return :(csgrammar_annotated($(QuoteNode(ex))))::AnnotatedGrammar
end

struct AnnotatedGrammar
   grammar::ContextSensitiveGrammar
   label_domains::Dict{String, BitArray}
   rule_annotations::Set{Tuple{Int, Any}}
end

function _process_expression(expression::Expr)::Tuple{
        ContextSensitiveGrammar, 
        Dict{String, BitVector},
        Set{Tuple{Int, Any}}
        }
    grammar = ContextSensitiveGrammar()
    bylabel = Dict{String,Vector{Int}}()
    rule_annotations = Set{Tuple{Int, Any}}()
    for e in expression.args
        if !(e isa Expr && e.head == :(=))
            continue
        end

        label = _get_label!(e)
        annotations = _get_annotations!(e)

        numrules_before = length(grammar.rules)
        add_rule!(grammar, e)
        numrules_after = length(grammar.rules)

        bylabel[label] = numrules_before+1:numrules_after

        for a in annotations
            for rule in bylabel[label]
                push!(rule_annotations, (rule, a))
            end
        end
    end
    return grammar, bylabel, rule_annotations
end

# gets the label from an expression
function _get_label!(e::Expr)::String
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
function _get_annotations!(e::Expr)::Vector{Any}
    # get the right hand side of a rule
    rhs = e.args[2]
    annotations = Any[]
    # parse annotations if present, i.e., of the form rule_rhs := annotations
    if rhs isa Expr && rhs.head == :(:=)
        annotations = rhs.args[2]
        if annotations isa Expr && annotations.head == :tuple
            annotations = annotations.args
        else
            annotations = [annotations]
        end

        # discard rule name
        e.args[2] = rhs.args[2]
    end
    return annotations
end

function _annotation2constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
    annotation::Any,
)::Vector{AbstractConstraint}
    if annotation isa Expr
        if annotation.head == :call
            annotation = annotation.args[1]
            labels = [String(arg) for arg in annotation.args[2:end]]
            labels_domain = _get_domain_from_labels(annotated_grammar.label_domains, labels, rule_index)

            if func_name == :identity
                _identity_constraints!(annotated_grammar, rule_index, labels_domain)
            elseif func_name == :inverse
                _inverse_constraints!(annotated_grammar, rule_index, labels_domain)
            elseif func_name == :distributive_over
                _distributive_over_constraints!(annotated_grammar, rule_index, labels_domain)
            else
                throw(ArgumentError("Annotation call $(annotation) at rule $(rule_index) not found!")) 
            end
        elseif annotation == :commutative
            _commutative_constraints!(annotated_grammar, rule_index)
        elseif annotation == :associativity
            _associativity_constraints!(annotated_grammar, rule_index)
        else
            throw(ArgumentError("Annotation $(annotation) at rule $(rule_index) not found!"))
        end
    end

    throw(ArgumentError("Annotation $(annotation) at rule $(rule_index) not found!"))
end

function _identity_constraints(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
    labels_domain::BitVector,
)
    addconstraint!(annotated_grammar.grammar,
        Forbidden(RuleNode(rule_index, [VarNode(:a), DomainRuleNode(labels_domain)]))
    )
    addconstraint!(annotated_grammar.grammar,
        Forbidden(RuleNode(rule_index, [DomainRuleNode(labels_domain), VarNode(:a)]))
    )
end

function _inverse_constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
    labels_domain::BitVector,
)::Vector{AbstractConstraint}
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
)::Vector{AbstractConstraint}
    addconstraint!(annotated_grammar.grammar,
        Forbidden(DomainRuleNode(labels_domain, [@rulenode rule_index{:x,:a}, @rulenode rule_index{:x,:b}]))
    )
    addconstraint!(annotated_grammar.grammar,
        Forbidden(DomainRuleNode(labels_domain, [@rulenode rule_index{:a,:x}, @rulenode rule_index{:b,:x}]))
    )
    if (rule_index, :commutative) ∈ annotated_grammar.rule_annotations
        addconstraint!(annotated_grammar.grammar,
            Forbidden(DomainRuleNode(labels_domain, [@rulenode rule_index{:x,:a}, @rulenode rule_index{:b,:x}]))
        )
        addconstraint!(annotated_grammar.grammar,
            Forbidden(DomainRuleNode(labels_domain, [@rulenode rule_index{:a,:x}, @rulenode rule_index{:x,:b}]))
        )
    end
end

function _commutative_constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
)::Vector{AbstractConstraint}
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
)::Vector{AbstractConstraint}
    addconstraint!(annotated_grammar.grammar, Forbidden(RuleNode(rule_index, [
                                RuleNode(rule_index, [VarNode(:a), VarNode(:b)]),
                                RuleNode(rule_index, [VarNode(:c), VarNode(:d)])
                            ])))
    if (rule_index, :commutative) ∈ annotated_grammar.rule_annotations
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

function _get_domain_from_labels(
    labels_to_domains::Dict{String, BitVector},
    labels::Vector{String},
    rule_index::Int
)::BitVector
    try
        return reduce(|, (labels_to_domains[l] for l in labels))
    catch e
        if e isa KeyError
            println("KeyError occurred while evaluating csgrammar_annotated for labels $(labels) at rule index $rule_index: ", e)
        end
        rethrow(e)
    end
end
