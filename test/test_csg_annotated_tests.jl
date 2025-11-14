@testitem "macro vs from expressions" begin
    
    direct = HerbConstraints.@csgrammar_annotated begin        
        zero::  Number = 0             
        one::  Number = 1     
        constants:: Number = |(2:4) 
        variables:: Number = x | y              
        minus::      Number = -Number           := identity("zero")
        plus::      Number = Number + Number    := (associative, commutative, identity("zero"), inverse("minus"))
        times::     Number = Number * Number    := (associative, commutative, identity("one"), distributive_over("plus"))
        Number = a | b | c
    end

    expr = quote        
        zero::  Number = 0             
        one::  Number = 1     
        constants:: Number = |(2:4) 
        variables:: Number = x | y              
        minus::      Number = -Number           := identity("zero")
        plus::      Number = Number + Number    := (associative, commutative, identity("zero"), inverse("minus"))
        times::     Number = Number * Number    := (associative, commutative, identity("one"), distributive_over("plus"))
        Number = a | b | c
    end

    from_expr = HerbConstraints.expr2csgrammar_annotated(expr)

    @test "$(direct)" == "$(from_expr)"
end

@testsetup module GrammarExpr 
    using HerbGrammar
    using HerbConstraints

    num =  quote
        Number = 0
        Number = 1
        Number = |(2:4)
        Number = x | y
        Number = -Number 
        Number = Number + Number
        Number = Number * Number
    end
    grammar = HerbGrammar.expr2csgrammar(num)
    unannotated = HerbConstraints.expr2csgrammar_annotated(num)

    num_annotated = quote        
        zero::  Number = 0             
        one::  Number = 1     
        constants:: Number = |(2:4) 
        variables:: Number = x | y              
        minus::      Number = -Number           := identity("zero")
        plus::      Number = Number + Number    := (associative, commutative, identity("zero"), inverse("minus"))
        Number = Number * Number    := (associative, commutative, identity("one"), distributive_over("plus"))
    end
    annotated = HerbConstraints.expr2csgrammar_annotated(num_annotated)
end

@testitem "backwards compatible to @csgrammar w/o annotations and labels" setup=[GrammarExpr] begin
    @test length(GrammarExpr.unannotated.grammar.rules) == length(GrammarExpr.grammar.rules)

    for (r1, r2) in zip(GrammarExpr.unannotated.grammar.rules, GrammarExpr.grammar.rules)
        @test r1 == r2
    end
    @test "$(GrammarExpr.unannotated.grammar)" == "$(GrammarExpr.grammar)"
end

@testitem "backwards compatible to @csgrammar with annotated and labeled" setup=[GrammarExpr] begin
    @test length(GrammarExpr.annotated.grammar.rules) == length(GrammarExpr.grammar.rules)

    for (r1, r2) in zip(GrammarExpr.annotated.grammar.rules, GrammarExpr.grammar.rules)
        @test r1 == r2
    end
    @test "$(GrammarExpr.annotated.grammar)" == "$(GrammarExpr.grammar)"
end

@testitem "labels" setup=[GrammarExpr] begin
    label_domains = GrammarExpr.annotated.label_domains
    rules = GrammarExpr.annotated.grammar.rules
    
    variables_rules = findall(==(true), label_domains["variables"])
    @test(rules[variables_rules[1]] == :(x))
    @test(rules[variables_rules[2]] == :(y))

    zero_rule = only(findall(==(true), label_domains["zero"]))
    @test(rules[zero_rule] == :(0))

    one_rule = only(findall(==(true), label_domains["one"]))
    @test(rules[one_rule] == :(1))

    constants_rules = findall(==(true), label_domains["constants"])
    for c in 2:4
        @test(rules[constants_rules[c-1]] == :($c))
    end

    minus_rule = only(findall(==(true), label_domains["minus"]))
    @test(rules[minus_rule] == :(-Number))

    plus_rule = only(findall(==(true), label_domains["plus"]))
    @assert(rules[plus_rule] == :(Number + Number))
end

@testitem "label duplication" begin
    expr = quote
        zero::  Number = 0   
        zero::  Number = 1
    end
    @test_throws ErrorException HerbConstraints.expr2csgrammar_annotated(expr)
end

@testitem "annotations" setup=[GrammarExpr] begin
    label_domains = GrammarExpr.annotated.label_domains
    rule_annotations = GrammarExpr.annotated.rule_annotations
    rules = GrammarExpr.annotated.grammar.rules

    variables_rules = findall(==(true), label_domains["variables"])
    @test(rule_annotations[variables_rules[1]] == [])
    @test(rule_annotations[variables_rules[2]] == [])

    zero_rule = only(findall(==(true), label_domains["zero"]))
    @test(rule_annotations[zero_rule] == [])

    one_rule = only(findall(==(true), label_domains["one"]))
    @test(rule_annotations[one_rule] == [])

    constants_rules = findall(==(true), label_domains["constants"])
    for r in constants_rules
        @test(rule_annotations[r] == [])
    end

    minus_rule = only(findall(==(true), label_domains["minus"]))
    annotations = rule_annotations[minus_rule]
    @test :(identity("zero")) in annotations

    plus_rule = only(findall(==(true), label_domains["plus"]))
    annotations = rule_annotations[plus_rule]
    @test :associative in annotations
    @test :commutative in annotations
    @test :(identity("zero")) in annotations
    @test :(inverse("minus")) in annotations

    times_rule = length(rules)
    annotations = rule_annotations[times_rule]
    @test :associative in annotations
    @test :commutative in annotations
    @test :(identity("one")) in annotations
    @test :(distributive_over("plus")) in annotations
end

@testitem "undefined annotation" begin
    expr = quote        
        Number = Number + Number := (unknown_annotation)
    end
    @test_throws ArgumentError HerbConstraints.expr2csgrammar_annotated(expr)
end 

@testitem "no label in call annotation" begin
    expr = quote        
        Number = Number + Number := (unknown_annotation(arg))
    end
    @test_throws KeyError HerbConstraints.expr2csgrammar_annotated(expr)
end

@testitem "undefined label in call annotation" begin
    expr = quote        
        plus :: Number = Number + Number := (unknown_annotation(plus))
    end
    @test_throws ArgumentError HerbConstraints.expr2csgrammar_annotated(expr)
end

@testsetup module HerbSearch 
    using HerbSearch
end

@testsetup module HerbGrammar 
    using HerbGrammar
end

@testitem "candidates generation" setup=[HerbSearch, GrammarExpr] begin
    @test length(GrammarExpr.grammar.constraints)==0
    @test length(GrammarExpr.annotated.grammar.constraints) == 25

    @test length(HerbSearch.BFSIterator(GrammarExpr.grammar, :Number, max_depth=3)) == 25207
    @test length(HerbSearch.BFSIterator(GrammarExpr.annotated.grammar, :Number, max_depth=3)) == 1172
end
