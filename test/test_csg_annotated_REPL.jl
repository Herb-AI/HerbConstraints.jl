using HerbConstraints
using HerbGrammar


    
    
    
    println("\n\n\nAnnotated grammar labels:\n $(annotated)")

    variables_rules = only(findall(==(true), annotated.label_domains["variables"]))
    @test(annotated.grammar.rules[variables_rules[1]] == :(x))
    @test(annotated.grammar.rules[variables_rules[2]] == :(y))