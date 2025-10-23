using TestItems

@testmodule HerbGrammar begin
    using HerbGrammar
end

@testitem "define grammar from expressions" begin
    
    direct = HerbConstraints.@csgrammar_annotated begin
        variables:: Number = x | y         
        zero::  Number = 0             
        one::  Number = 1     
        constants:: Number = |(2:10)              
        minus::      Number = -Number           := (identity("zero"))
        plus::      Number = Number + Number    := (associative, commutative, identity("zero"), inverse("minus"))
        times::     Number = Number * Number    := (associative, commutative, identity("one"), distributive_over("plus"))
    end

    expr = quote
        variables:: Number = x | y         
        zero::  Number = 0             
        one::  Number = 1     
        constants:: Number = |(2:10)              
        minus::      Number = -Number           := (identity("zero"))
        plus::      Number = Number + Number    := (associative, commutative, identity("zero"), inverse("minus"))
        times::     Number = Number * Number    := (associative, commutative, identity("one"), distributive_over("plus"))
    end

    from_expr = HerbConstraints.expr2csgrammar_annotated(expr)

    @test "$(direct)" == "$(from_expr)"
end

@testmodule GrammarExpr begin
    num =  quote
        Number = x | y
        Number = 0
        Number = 1
        Number = |(2:10)
        Number = -Number 
        Number = Number + Number
        Number = Number * Number
    end

    num_annotated = quote
        variables:: Number = x | y         
        zero::  Number = 0             
        one::  Number = 1     
        constants:: Number = |(2:10)              
        minus::      Number = -Number           := (identity("zero"))
        plus::      Number = Number + Number    := (associative, commutative, identity("zero"), inverse("minus"))
        times::     Number = Number * Number    := (associative, commutative, identity("one"), distributive_over("plus"))
    end

end

@testitem "backwards compatible to @csgrammar w/o annotations and labels" setup=[HerbGrammar, GrammarExpr] begin
    annotated = HerbConstraints.expr2csgrammar_annotated(GrammarExpr.num)
    grammar = HerbGrammar.expr2csgrammar(GrammarExpr.num)

    @test length(annotated.grammar.rules) == length(grammar.rules)

    for (r1, r2) in zip(annotated.grammar.rules, grammar.rules)
        @test r1 == r2
    end
end

@testitem "backwards compatible to @csgrammar with annotated and labeled" setup=[HerbGrammar, GrammarExpr] begin
    annotated = HerbConstraints.expr2csgrammar_annotated(GrammarExpr.num_annotated)
    grammar = HerbGrammar.expr2csgrammar(GrammarExpr.num)

    @test length(annotated.grammar.rules) == length(grammar.rules)

    for (r1, r2) in zip(annotated.grammar.rules, grammar.rules)
        @test r1 == r2
    end
end


@testitem "check that labels are correctly added" setup=[HerbGrammar, GrammarExpr] begin
    annotated = HerbConstraints.expr2csgrammar_annotated(GrammarExpr.num_annotated)
    println("\n\n\nAnnotated grammar labels:\n $(annotated)")

    variables_rules = findall(==(true), annotated.label_domains["variables"])
    @test(annotated.grammar.rules[variables_rules[1]] == :(x))
    @test(annotated.grammar.rules[variables_rules[2]] == :(y))

    zero_rule = only(findall(==(true), annotated.label_domains["zero"]))
    @test(annotated.grammar.rules[zero_rule] == :(0))

    one_rule = only(findall(==(true), annotated.label_domains["one"]))
    @test(annotated.grammar.rules[one_rule] == :(1))

    constants_rules = findall(==(true), annotated.label_domains["constants"])
    for c in 2:10
        @test(annotated.grammar.rules[constants_rules[c-1]] == :($c))
    end

    minus_rule = only(findall(==(true), annotated.label_domains["minus"]))
    @test(annotated.grammar.rules[minus_rule] == :(-Number))

    plus_rule = only(findall(==(true), annotated.label_domains["plus"]))
    @assert(annotated.grammar.rules[plus_rule] == :(Number + Number))

    times_rule = only(findall(==(true), annotated.label_domains["times"]))
    @test(annotated.grammar.rules[times_rule] == :(Number * Number))
end

@testitem "check annotations are correctly added" setup=[HerbGrammar, GrammarExpr] begin
    annotated = HerbConstraints.expr2csgrammar_annotated(GrammarExpr.num_annotated)


    variables_rules = findall(==(true), annotated.label_domains["variables"])
    @test(annotated.rule_annotations[variables_rules[1]] == [])
    @test(annotated.rule_annotations[variables_rules[2]] == [])

    zero_rule = only(findall(==(true), annotated.label_domains["zero"]))
    @test(annotated.rule_annotations[zero_rule] == [])

    one_rule = only(findall(==(true), annotated.label_domains["one"]))
    @test(annotated.rule_annotations[one_rule] == [])

    constants_rules = findall(==(true), annotated.label_domains["constants"])
    for r in constants_rules
        @test(annotated.rule_annotations[r] == [])
    end
    
    minus_rule = only(findall(==(true), annotated.label_domains["minus"]))
    annotations = annotated.rule_annotations[minus_rule]
    @test :(identity("zero")) in annotations

    plus_rule = only(findall(==(true), annotated.label_domains["plus"]))
    annotations = annotated.rule_annotations[plus_rule]
    @test :associative in annotations
    @test :commutative in annotations
    @test :(identity("zero")) in annotations
    @test :(inverse("minus")) in annotations

    times_rule = only(findall(==(true), annotated.label_domains["times"]))
    annotations = annotated.rule_annotations[times_rule]
    @test :associative in annotations
    @test :commutative in annotations
    @test :(identity("one")) in annotations
    @test :(distributive_over("plus")) in annotations
end
