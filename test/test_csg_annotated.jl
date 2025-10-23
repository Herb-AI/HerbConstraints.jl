using TestItems

@testmodule HerbGrammar begin
    using HerbGrammar
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
    annotated = HerbConstraints.@csgrammar_annotated GrammarExpr.num_annotated
    grammar = HerbGrammar.@csgrammar GrammarExpr.num

    @test length(annotated.grammar.rules) == length(grammar.rules)

    for (r1, r2) in zip(annotated.grammar.rules, grammar.rules)
        @test r1 == r2
    end
end

