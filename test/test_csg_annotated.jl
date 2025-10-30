using TestItems

@testmodule HerbGrammar begin
    using HerbGrammar
end

@testitem "define grammar from expressions" begin
    
    direct = HerbConstraints.@csgrammar_annotated begin
        zero::  Number = 0             
        one::  Number = 1     
        constants:: Number = |(2:4)         
        variables:: Number = x | y              
        minus::      Number = -Number           := (identity("zero"))
        plus::      Number = Number + Number    := (associative, commutative, identity("zero"), inverse("minus"))
        times::     Number = Number * Number    := (associative, commutative, identity("one"), distributive_over("plus"))
    end

    expr = quote      
        zero::  Number = 0             
        one::  Number = 1     
        constants:: Number = |(2:4)  
        variables:: Number = x | y               
        minus::      Number = -Number           := (identity("zero"))
        plus::      Number = Number + Number    := (associative, commutative, identity("zero"), inverse("minus"))
        times::     Number = Number * Number    := (associative, commutative, identity("one"), distributive_over("plus"))
    end

    from_expr = HerbConstraints.expr2csgrammar_annotated(expr)

    @test "$(direct)" == "$(from_expr)"
end

@testmodule GrammarExpr begin
    num =  quote
        Number = 0
        Number = 1
        Number = |(2:4)
        Number = x | y
        Number = -Number 
        Number = Number + Number
        Number = Number * Number
        Number = a | b | c
    end

    num_annotated = quote        
        zero::  Number = 0             
        one::  Number = 1     
        constants:: Number = |(2:4) 
        variables:: Number = x | y              
        minus::      Number = -Number           := (identity("zero"))
        plus::      Number = Number + Number    := (associative, commutative, identity("zero"), inverse("minus"))
        times::     Number = Number * Number    := (associative, commutative, identity("one"), distributive_over("plus"))
        Number = a | b | c
    end

end

@testitem "backwards compatible to @csgrammar w/o annotations and labels" setup=[HerbGrammar, GrammarExpr] begin
    annotated = HerbConstraints.expr2csgrammar_annotated(GrammarExpr.num)
    grammar = HerbGrammar.expr2csgrammar(GrammarExpr.num)

    @test length(annotated.grammar.rules) == length(grammar.rules)

    for (r1, r2) in zip(annotated.grammar.rules, grammar.rules)
        @test r1 == r2
    end
    @test "$(annotated.grammar)" == "$(grammar)"
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

    variables_rules = findall(==(true), annotated.label_domains["variables"])
    @test(annotated.grammar.rules[variables_rules[1]] == :(x))
    @test(annotated.grammar.rules[variables_rules[2]] == :(y))

    zero_rule = only(findall(==(true), annotated.label_domains["zero"]))
    @test(annotated.grammar.rules[zero_rule] == :(0))

    one_rule = only(findall(==(true), annotated.label_domains["one"]))
    @test(annotated.grammar.rules[one_rule] == :(1))

    constants_rules = findall(==(true), annotated.label_domains["constants"])
    for c in 2:4
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

#=
TODO: change constraint testing format.
Each constraint in the grammar should have:
  * a filtered case, that is filtered by that constraint only
  * an equivalent unfiltered case, that is allowed by all constraints
Also, make sure all constraints that can be in a grammar are tested.
    For example all combinations of associative, commutative, distributive_over
=#

@testsnippet Candidates begin
    using HerbSearch
    grammar = HerbGrammar.expr2csgrammar(GrammarExpr.num)
    grammar_candidates = ["$(HerbGrammar.rulenode2expr(c, grammar))" 
        for c ∈ HerbSearch.BFSIterator(grammar, :Number, max_depth=3)]

    annotated = HerbConstraints.expr2csgrammar_annotated(GrammarExpr.num_annotated)
    annotated_candidates = ["$(HerbGrammar.rulenode2expr(c, annotated.grammar))" 
        for c ∈ HerbSearch.BFSIterator(annotated.grammar, :Number, max_depth=3)]
  
    function in_both(candidate)
        @test (candidate ∈ grammar_candidates)
        @test (candidate ∈ annotated_candidates)
    end
    function filtered(candidate) 
        @test (candidate ∈ grammar_candidates)
        @test (candidate ∉ annotated_candidates) 
    end
end

@testitem "check constraints" setup=[HerbGrammar, GrammarExpr, Candidates] begin
    @test length(grammar.constraints)==0
    @test length(annotated.grammar.constraints) == 19

    @test length(annotated_candidates) == 4741
    @test length(grammar_candidates) == 97030

    # minus identity("zero")
    in_both("0")
    filtered("-0")

    # plus associative 
    in_both("2 + (3 + x)")
    filtered("(2 + 3) + x")
    filtered("(1 + 1) + (1 + 1)")

    # plus associative + commutative
    in_both("2 + (3 + 4)")
    filtered("(3 + 4) + 2")
    filtered("3 + (2 + 4)")
    filtered("(2 + 4) + 3")
    filtered("4 + (2 + 3)")
    filtered("(2 + 3) + 4")
    in_both("(b + c) + a")
    filtered("a + (b + c)")
    filtered("(a + c) + b")
    filtered("b + (a + c)")
    filtered("(a + b) + c")
    filtered("c + (a + b)")

    # plus commutative
    in_both("2 + x")
    filtered("x + 2")
    in_both("2 + a")
    filtered("a + 2")
    in_both("a + b")
    filtered("b + a")

    # plus identity("zero")
    in_both("x")
    filtered("0 + x")

    # plus inverse("minus")
    filtered("y + -y")

    # times associative
    in_both("2 * (x * y)")
    filtered("(2x) * y")
    filtered("(1 * 2) * (3 * 4)")

    # times associative + commutative
    filtered("x * (2y)")
    filtered("y * (2x)")
    
    # times commutative
    in_both("4y")
    filtered("y * 4")

    # times identity("one")
    in_both("x")
    filtered("1x")
    
    # times distributive_over("plus")
    in_both("2 * (x + y)")
    filtered("2x + 2y")
    filtered("2x + 3x")

    # times distributive_over("plus") + plus commutative
    filtered("2 * 3 + 3x")
    filtered("3x + x * y")
end
