"""
    expr2csgrammar(expression::Expr)::AnnotatedGrammar  

A function for converting an `Expr` to a [`AnnotatedGrammar`](@ref).
If the expression is hardcoded, you should use the [`@csgrammar_annotated`](@ref) macro.
Only expressions in the correct format (see [`csgrammar_annotated`](@ref)) can be converted.

# Examples
```julia-repl
    num_annotated = quote        
        zero::  Number = 0             
        one::  Number = 1     
        constants:: Number = |(2:4) 
        variables:: Number = x | y              
        minus::      Number = -Number           := (identity("zero"))
        plus::      Number = Number + Number    := (associative, commutative, identity("zero"), inverse("minus"))
        times::     Number = Number * Number    := (associative, commutative, identity("one"), distributive_over("plus"))
    end
    annotated_grammar = HerbConstraints.expr2csgrammar_annotated(num_annotated)
"""
function expr2csgrammar_annotated(expression::Expr)::AnnotatedGrammar  
    grammar, bylabel, rule_annotations = _process_expression(expression)

    labels = Dict(label => BitArray(r ∈ bylabel[label] for r ∈ 1:length(grammar.rules)) for label ∈ keys(bylabel) if label != NaN)

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

A macro wrapper for the [`expr2csgrammar`](@ref) function.
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

# Examples

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
macro csgrammar_annotated(ex)
    return :(expr2csgrammar_annotated($(QuoteNode(ex))))
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

"""
    get_grammar(annotated_grammar::AnnotatedGrammar)::ContextSensitiveGrammar

Returns the underlying ContextSensitiveGrammar.
"""
function get_grammar(annotated_grammar::AnnotatedGrammar)::ContextSensitiveGrammar
    return annotated_grammar.grammar
end

"""
    get_label_domains(annotated_grammar::AnnotatedGrammar)::Dict{String, BitArray}

Returns the label domains dictionary.
"""
function get_label_domains(annotated_grammar::AnnotatedGrammar)::Dict{String, BitArray}
    return annotated_grammar.label_domains
end

"""
    get_rule_annotations(annotated_grammar::AnnotatedGrammar)::Dict{Int,Vector{Any}}

Returns the rule annotations dictionary.
"""
function get_rule_annotations(annotated_grammar::AnnotatedGrammar)::Dict{Int,Vector{Any}}
    return annotated_grammar.rule_annotations
end

function _process_expression(expression)::Tuple{
        ContextSensitiveGrammar, 
        Dict{String,Vector{Int}},
        Dict{Int,Vector{Any}},
        }
    grammar = ContextSensitiveGrammar()
    bylabel = Dict{String,Vector{Int}}()
    rule_annotations = Dict{Int,Vector{Any}}()

    expr = deepcopy(expression)
    Base.remove_linenums!(expr)
    for e in expr.args
        label, annotations, rule_lhs, rule_rhs = @match e begin
            :($lhs = $rhs) => begin
                label, rule_lhs = _get_label(lhs)
                annotations, rule_rhs = _get_annotations(rhs)
                label, annotations, rule_lhs, rule_rhs
            end
            _ => error("Expected rule definition of the form lhs = rhs, got: $e (rule $(length(grammar.rules)+1))")
        end

        numrules_before = length(grammar.rules)
        add_rule!(grammar, :($rule_lhs = $rule_rhs))
        numrules_after = length(grammar.rules)
        new_rules = collect(numrules_before+1:numrules_after)

        if label != nothing
            if label ∈ keys(bylabel)
                error("Label $label used for multiple rules!")
            end
            bylabel[label] = new_rules
        end

        for rule in new_rules
            rule_annotations[rule] = annotations
        end
    end
    return grammar, bylabel, rule_annotations
end

# gets the label from an expression
function _get_label(lhs) #::Tuple{Union{String, Nothing}, Any}
    @match lhs begin
        :($label_name :: $rule_lhs) => return string(label_name), rule_lhs
        _ => return nothing, lhs
    end
end

# gets the annotation from an expression
function _get_annotations(rhs) #::Tuple{Vector{Any}, Any}
    @match rhs begin
        :($rule_rhs := ($(annotations...),)) => return [annotations...], rule_rhs
        :($rule_rhs := $annotations) => return [annotations], rule_rhs
        _ => return [], rhs
    end
end

function _annotation2constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
    annotation::Any,
)
    @match annotation begin
        Expr(:call, name_, arg_) => begin
            annotation_name = name_
            labels_domain = get_label_domains(annotated_grammar)[String(arg_)]
            label_index = only(findall(==(true), labels_domain))
            @match annotation_name begin
                :identity => _identity_constraints!(annotated_grammar, rule_index, label_index)
                :inverse => _inverse_constraints!(annotated_grammar, rule_index, label_index)
                :distributive_over => _distributive_over_constraints!(annotated_grammar, rule_index, label_index)
                _ => throw(ArgumentError("Annotation call $(annotation) not found! (rule $(rule_index))")) 
            end
        end
        :commutative => _commutative_constraints!(annotated_grammar, rule_index)
        :associative => _associativity_constraints!(annotated_grammar, rule_index)
        _ => throw(ArgumentError("Annotation $(annotation) not found! (rule $(rule_index))"))
    end
end


function _identity_constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
    label_index::Int,
)
    num_label_children = length(annotated_grammar.grammar.childtypes[label_index])
    label_children = [VarNode(Symbol("y_$(i)")) for i in 1:num_label_children]
    label_node = RuleNode(label_index, label_children)

    num_rule_children = length(annotated_grammar.grammar.childtypes[rule_index])
    rule_non_label_children = [VarNode(Symbol("x_$(i)")) for i in 1:num_rule_children-1]
    for i in 1:num_rule_children
        rule_children = Vector{AbstractRuleNode}(copy(rule_non_label_children))
        insert!(rule_children, i,label_node)
        addconstraint!(annotated_grammar,
            Forbidden(RuleNode(rule_index, rule_children))
        )
    end
end

function _inverse_constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
    label_index::Int,
)
    addconstraint!(annotated_grammar,
        Forbidden(RuleNode(rule_index, [RuleNode(label_index, [VarNode(:x)]), VarNode(:x)]))
    )
    addconstraint!(annotated_grammar,
        Forbidden(RuleNode(rule_index, [VarNode(:x), RuleNode(label_index, [VarNode(:x)])]))
    )
    #TODO: make sure this always holds (mathematically, by definition)
    addconstraint!(annotated_grammar,
        Forbidden(RuleNode(label_index, [RuleNode(label_index, [VarNode(:a)])]))
    )
    # TODO: if has identity, add constraint for inverse of identity
    # TODO: if associative, any hierarchy of rule of :x and inverse(:x) is forbidden
end

function _distributive_over_constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
    label_index::Int,
)
    rulenode_ax = RuleNode(rule_index, [VarNode(:a), VarNode(:x)])
    rulenode_bx = RuleNode(rule_index, [VarNode(:b), VarNode(:x)])
    rulenode_xa = RuleNode(rule_index, [VarNode(:x), VarNode(:a)])
    rulenode_xb = RuleNode(rule_index, [VarNode(:x), VarNode(:b)])

    addconstraint!(annotated_grammar,
        Forbidden(RuleNode(label_index, [rulenode_ax, rulenode_bx]))
    )
    addconstraint!(annotated_grammar,
        Forbidden(RuleNode(label_index, [rulenode_xa, rulenode_xb]))
    )
    if :commutative ∈ annotated_grammar.rule_annotations[rule_index]
        addconstraint!(annotated_grammar,
            Forbidden(RuleNode(label_index, [rulenode_ax, rulenode_xb]))
        )
        addconstraint!(annotated_grammar,
            Forbidden(RuleNode(label_index, [rulenode_xa, rulenode_bx]))
        )
    end
    # TODO: we should add this only if the 2(*identity) is in the grammar
    # if :identity ∈ annotated_grammar.rule_annotations[rule_index]
    #     addconstraint!(annotated_grammar,
    #         Forbidden(RuleNode(label_index, [VarNode(:x), VarNode(:x)]))
    #     )
    # end
end

function _commutative_constraints!(
    annotated_grammar::AnnotatedGrammar,
    rule_index::Int,
)
    #TODO: preformance wise, add one domain constraint for all commutative rules
    addconstraint!(annotated_grammar,
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
    if :commutative ∈ annotated_grammar.rule_annotations[rule_index]
        # allow only to repeat the operation in a path formation with ordered operands
        #   * will lean right while smaller then the rule, and then left
        addconstraint!(annotated_grammar, 
            Forbidden(RuleNode(rule_index, [
                RuleNode(rule_index, [VarNode(:a), VarNode(:b)]),
                RuleNode(rule_index, [VarNode(:c), VarNode(:d)])
            ]))
            )
        child = RuleNode(rule_index, [VarNode(:x), VarNode(:y)])
        addconstraint!(annotated_grammar, 
            Ordered(
                RuleNode(rule_index, [VarNode(:w), child]),
                [:w, :x],
            ))
        addconstraint!(annotated_grammar, 
            Ordered(
                RuleNode(rule_index, [child, VarNode(:w)]),
                [:y, :w],
            ))
        # TODO: combine to one constraint when we allow constraints on VarNodes
        num_children = length.(annotated_grammar.grammar.childtypes)
        for n in Set(num_children[1:rule_index-1])
            dom = BitVector([i<rule_index && n == num_children[i] for i in 1:length(annotated_grammar.grammar.rules)])
            addconstraint!(annotated_grammar, 
                Forbidden(RuleNode(rule_index, [
                    RuleNode(rule_index, [
                        DomainRuleNode(dom, [VarNode(Symbol("var_$(i)")) for i in 1:n]),
                        VarNode(:y)
                    ]),
                    VarNode(:w)
                ]))
                )
        end
        # TODO: if we also have an unary inverse, make the inverse invisible to the ordering
    else
        # allow only to repeat the operation in a left leaning path formation
        addconstraint!(annotated_grammar, 
            Forbidden(RuleNode(rule_index, [
                VarNode(:c),
                RuleNode(rule_index, [VarNode(:a), VarNode(:b)])
            ]))
            )
    end
end

"""
    addconstraint!(annotated_grammar::AnnotatedGrammar, constraint::Constraint)
Adds a constraint to the underlying ContextSensitiveGrammar.
"""
function HerbGrammar.addconstraint!(annotated_grammar::AnnotatedGrammar, constraint::Constraint)
    addconstraint!(annotated_grammar.grammar, constraint)
end


## Ideas for future annotations
# - minus multiplication relationship
# - minus is comutative over plus
# - boolean algebra annotations
# - lists annotations
