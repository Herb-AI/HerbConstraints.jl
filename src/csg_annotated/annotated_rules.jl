
"""
    module AnnotatedRules

This module contains predefined rules to construct annotated grammars for common algebraic structures.
Multiple expressions for algebraic structures, along with self defined rules in a `quote` block, can be combined using the `concat_quotes` function.
Those expressions can be used with the `expr2csgrammar_annotated` function to create `AnnotatedGrammar` instances.
Defined structures currently include `Numbers` and `Booleans`, each with relevant operations and annotations.
"""
module AnnotatedRules

export concat_quotes, Numbers, Booleans

"""
    concat_quotes(qs::Expr...)::Expr

Concatenates multiple quoted expressions into a single quoted expression.
"""
function concat_quotes(qs::Expr...)::Expr
    return Expr(:block, reduce(vcat, (q.args for q in qs))...)
end

Numbers = quote         
    zero::  Number = 0             
    one::   Number = 1              
    minus:: Number = -Number            := (
        identity("zero")
        )
    plus::  Number = Number + Number    := (
        associative,
        commutative, 
        identity("zero"), 
        inverse("minus")
        )
    mul::   Number = Number * Number    := (
        associative, 
        commutative, 
        identity("one"), 
        distributive_over("plus"),
        annihilator("zero")
        )
end

Booleans = quote
    # false:: Boolean = false
    # true::  Boolean = true
    and::   Boolean = Boolean & Boolean  := (
        commutative, 
        associative, 
        idempotent,
        # identity("true"), 
        # annihilator("false"),
        distributive_over("or"),
        absorptive_over("or"),
        inverse("not")
        )
    or::    Boolean = Boolean | Boolean  := (
        commutative, 
        associative, 
        idempotent,
        # identity("false"), 
        # annihilator("true"),
        distributive_over("and"),
        absorptive_over("and"),
        inverse("not")
        )
    not::   Boolean = ~Boolean  
end

end # module AnnotatedGrammars