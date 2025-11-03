using TestItems

"""
This test file tests that constraints in annotated grammars work as intended. 
To make sure that constraints are tested properly:
    * Each constraint should bad out at least one "bad" program uniquely
    * At least one "good" program that is equivalent should pass all constraints
Use "Run Tests with Coverage" to ensure that all constraints are covered by the tests.
Make sure all tests have Total != 0 tests (that you did not forget to call the testing function).
Recommended to turn on notice_prints by default when developing tests.
"""

@testmodule check_constraints_module begin
    using HerbConstraints
    using HerbGrammar
    using Test

    function check_constraints(
        annotated_grammar::ContextSensitiveGrammar,
        good_programs::Vector{RuleNode},
        bad_programs::Vector{RuleNode};
        forgive_missing_constraints::Bool=false,
        notice_prints::Bool=true
    )
        @assert length(good_programs) >= 1
        for p ∈ good_programs
            # println("Checking good program: ", HerbGrammar.rulenode2expr(p, annotated_grammar))
            for c ∈ annotated_grammar.constraints
                if !((@test HerbConstraints.check_tree(c, p)) isa Test.Pass)
                    if notice_prints
                        println()
                        println("Fail information:")
                        println("$(HerbGrammar.rulenode2expr(p, annotated_grammar)) (good) was filtered by:")
                        println(c)
                        println()
                    end
                end
            end
        end
        tested_constraints = Set{Any}()
        for p ∈ bad_programs
            # println("Checking bad program: ", HerbGrammar.rulenode2expr(p, annotated_grammar))
            constrained_by = Vector{Any}()
            for c ∈ annotated_grammar.constraints
                if !HerbConstraints.check_tree(c, p)
                    push!(constrained_by, c)
                end
            end
            @test length(constrained_by) >= 1
            if length(constrained_by) > 1 && notice_prints
                println()
                println("Notice:")
                println("$(HerbGrammar.rulenode2expr(p, annotated_grammar)) (bad) was filtered by multiple constraints")
                [println(c) for c in constrained_by]
            elseif length(constrained_by) == 1
                push!(tested_constraints, constrained_by[1])
            elseif length(constrained_by) == 0
                println()
                println("Fail information:")
                println("$(HerbGrammar.rulenode2expr(p, annotated_grammar)) (bad) was not filtered by any constraint")
                println("The rulenode: $p")
                println("The grammar constraints:")
                [println(c) for c in annotated_grammar.constraints]
            end
        end
        if ((!forgive_missing_constraints || notice_prints) 
            && (length(tested_constraints) != length(annotated_grammar.constraints)))
            println()
            if !forgive_missing_constraints
                @test (length(tested_constraints) == length(annotated_grammar.constraints))
                println("Fail information:") 
            else
                println("Notice:")
            end
            println("Not all constraints were tested.")
            # println("Tested constraints:")
            # [println(c) for c in tested_constraints]
            println("Missing constraints:")
            [println(c) for c in setdiff(Set(annotated_grammar.constraints), tested_constraints)]
            println()
        end
    end
end

@testitem "identity" setup=[check_constraints_module] begin
    annotated_grammar = quote        
        zero::      Number = 0
        var::       Number = x 
        plus::      Number = Number + Number    := (identity("zero"))
        minus::     Number = -Number             := (identity("zero"))
    end
    annotated = HerbConstraints.expr2csgrammar_annotated(annotated_grammar)
    zero = only(findall(==(true), annotated.label_domains["zero"]))
    x = only(findall(==(true), annotated.label_domains["var"]))
    plus = only(findall(==(true), annotated.label_domains["plus"]))
    minus = only(findall(==(true), annotated.label_domains["minus"]))
    
    RN = check_constraints_module.HerbGrammar.RuleNode
    good = Vector{RN}()
    bad = Vector{RN}()

    # plus identity("zero")
    push!(good, RN(x))
    push!(bad, RN(plus, [
        RN(x), 
        RN(zero)
    ]))
    push!(bad, RN(plus, [
        RN(zero), 
        RN(x)
    ]))

    # minus identity("zero")
    push!(good, RN(x))
    push!(bad, RN(minus, [RN(zero)]))

    check_constraints_module.check_constraints(
        annotated.grammar,
        good,
        bad
    )
end

@testitem "inverse" setup=[check_constraints_module] begin
    annotated_grammar = quote        
        zero::      Number = 0
        var::       Number = x | y 
        plus::      Number = Number + Number    := (inverse("minus"))
        minus::     Number = -Number            
    end
    annotated = HerbConstraints.expr2csgrammar_annotated(annotated_grammar)
    zero = only(findall(==(true), annotated.label_domains["zero"]))
    x,y = findall(==(true), annotated.label_domains["var"])
    plus = only(findall(==(true), annotated.label_domains["plus"]))
    minus = only(findall(==(true), annotated.label_domains["minus"]))
    
    RN = check_constraints_module.HerbGrammar.RuleNode
    good = Vector{RN}()
    bad = Vector{RN}()

    # plus inverse("minus")
    push!(good, RN(zero))
    push!(good, RN(plus, [
        RN(x), 
        RN(minus, [RN(y)])
    ]))
    push!(good, RN(plus, [
        RN(minus, [RN(x)]),
        RN(y)
    ]))

    push!(bad, RN(plus, [
        RN(x), 
        RN(minus, [RN(x)])
    ]))
    push!(bad, RN(plus, [
        RN(minus, [RN(x)]),
        RN(x)
    ]))

    push!(bad, RN(minus, [
        RN(minus, [
            RN(y)
        ])
    ]))

    check_constraints_module.check_constraints(
        annotated.grammar,
        good,
        bad
    )
end

@testitem "distributive_over" setup=[check_constraints_module] begin
    annotated_grammar = quote 
        var::       Number = x | y | z
        plus::      Number = Number + Number    
        times::     Number = Number * Number    := (distributive_over("plus"))
    end
    annotated = HerbConstraints.expr2csgrammar_annotated(annotated_grammar)
    x,y,z = findall(==(true), annotated.label_domains["var"])
    plus = only(findall(==(true), annotated.label_domains["plus"]))
    times = only(findall(==(true), annotated.label_domains["times"]))
    
    RN = check_constraints_module.HerbGrammar.RuleNode
    good = Vector{RN}()
    bad = Vector{RN}()

    # times distributive_over("plus")
    push!(good, RN(times, [
        RN(plus, [
            RN(x),
            RN(y)
        ]),
        RN(z)
    ]))
    push!(bad, RN(plus, [
        RN(times, [
            RN(x),
            RN(z)
        ]),
        RN(times, [
            RN(y),
            RN(z)
        ])
    ]))

    push!(good, RN(times, [
        RN(z),
        RN(plus, [
            RN(x),
            RN(y)
        ])
    ]))
    push!(bad, RN(plus, [
        RN(times, [
            RN(z),
            RN(x)
        ]),
        RN(times, [
            RN(z),
            RN(y)
        ])
    ]))

    push!(good, RN(plus, [
        RN(times, [
            RN(x),
            RN(z)
        ]),
        RN(times, [
            RN(z),
            RN(y)
        ])
    ]))
    push!(good, RN(plus, [
        RN(times, [
            RN(z),
            RN(x)
        ]),
        RN(times, [
            RN(y),
            RN(z)
        ])
    ]))

    push!(good, RN(plus, [
        RN(x),
        RN(x)
    ]))

    check_constraints_module.check_constraints(
        annotated.grammar,
        good,
        bad
    )
end

@testitem "distributive_over+commutative" setup=[check_constraints_module] begin
    annotated_grammar = quote 
        var::       Number = x | y | z
        plus::      Number = Number + Number    
        times::     Number = Number * Number    := (distributive_over("plus"), commutative)
    end
    annotated = HerbConstraints.expr2csgrammar_annotated(annotated_grammar)
    x,y,z = findall(==(true), annotated.label_domains["var"])
    plus = only(findall(==(true), annotated.label_domains["plus"]))
    times = only(findall(==(true), annotated.label_domains["times"]))
    
    RN = check_constraints_module.HerbGrammar.RuleNode
    good = Vector{RN}()
    bad = Vector{RN}()

    # times distributive_over("plus")
    push!(good, RN(times, [
        RN(z),
        RN(plus, [
            RN(x),
            RN(y)
        ])
    ]))

    push!(bad, RN(times, [
        RN(plus, [
            RN(x),
            RN(y)
        ]),
        RN(z)
    ]))

    push!(bad, RN(plus, [
        RN(times, [
            RN(x),
            RN(z)
        ]),
        RN(times, [
            RN(y),
            RN(z)
        ])
    ]))
    push!(bad, RN(plus, [
        RN(times, [
            RN(x),
            RN(y)
        ]),
        RN(times, [
            RN(x),
            RN(z)
        ])
    ]))

    push!(bad, RN(plus, [
        RN(times, [
            RN(x),
            RN(y)
        ]),
        RN(times, [
            RN(y),
            RN(z)
        ])
    ]))
    push!(bad, RN(plus, [
        RN(times, [
            RN(y),
            RN(z)
        ]),
        RN(times, [
            RN(x),
            RN(y)
        ])
    ]))

    push!(good, RN(plus, [
        RN(x),
        RN(x)
    ]))

    check_constraints_module.check_constraints(
        annotated.grammar,
        good,
        bad
    )
end

@testitem "associativity+commutative" setup=[check_constraints_module] begin
    annotated_grammar = quote        
        constants:: Number = |(1:4) 
        smallvars:: Number = x | y 
        plus::      Number = Number + Number    := (associative, commutative)
        bigvars:: Number = a | b | c
    end
    annotated = HerbConstraints.expr2csgrammar_annotated(annotated_grammar)
  
    plus = only(findall(==(true), annotated.label_domains["plus"]))
    consts = findall(==(true), annotated.label_domains["constants"])
    x,y = findall(==(true), annotated.label_domains["smallvars"])
    a,b,c = findall(==(true), annotated.label_domains["bigvars"])


    RN = check_constraints_module.HerbGrammar.RuleNode

    good = Vector{RN}()
    bad = Vector{RN}()

    # basic ordering
    push!(good, RN(plus, [
        RN(consts[1]),
        RN(plus, [
            RN(consts[2]),
            RN(plus, [
                RN(consts[3]), 
                RN(consts[4])
            ])
        ])
    ]))
    push!(good, RN(plus, [
        RN(consts[1]),
        RN(plus, [
            RN(consts[1]),
            RN(plus, [
                RN(consts[1]), 
                RN(consts[1])
            ])
        ])
    ]))
    push!(bad, RN(plus, [
        RN(consts[3]), 
        RN(consts[2])
    ]))
    push!(bad, RN(plus, [
        RN(b), 
        RN(a)
    ]))
    push!(bad, RN(plus, [
        RN(b), 
        RN(plus, [
            RN(a), 
            RN(b)
        ])
    ]))
    push!(bad, RN(plus, [
        RN(consts[3]), 
        RN(plus, [
            RN(consts[2]), 
            RN(consts[3])
        ])
    ]))
    push!(bad, RN(plus, [
        RN(plus, [
            RN(a), 
            RN(b)
        ]),
        RN(a)
    ]))
    push!(bad, RN(plus, [
        RN(plus, [
            RN(consts[2]), 
            RN(consts[3])
        ]),
        RN(consts[2])
    ]))


    # permutations of x<y<plus<a<b<c
    push!(good, RN(plus, [
        RN(x), 
        RN(plus, [
            RN(y), 
            RN(plus, [
                RN(plus, [
                    RN(a), 
                    RN(b)
                ]),
                RN(c)
            ])
        ])
    ]))
    push!(bad, RN(plus, [
        RN(x), 
        RN(plus, [
            RN(plus, [
                RN(plus, [
                    RN(y), 
                    RN(a)
                ]),
                RN(b)
            ]),
            RN(c)
        ])
    ]))
    push!(bad, RN(plus, [
        RN(plus, [
            RN(plus, [
                RN(plus, [
                    RN(x), 
                    RN(y)
                ]),
                RN(a)
            ]),
            RN(b)
        ]),
        RN(c)
    ]))

    check_constraints_module.check_constraints(
        annotated.grammar,
        good,
        bad,
        # parallel plus will entail infinite depth - so we want the constraint but can't test it
        forgive_missing_constraints=true,
        notice_prints=false
    )
end

@testitem "associativeity-commutative" setup=[check_constraints_module] begin
    annotated_grammar = quote        
        constants:: Number = |(1:4) 
        smallvars:: Number = x | y 
        mult::      Number = Number * Number    := associative
        bigvars:: Number = a | b | c
    end
    annotated = HerbConstraints.expr2csgrammar_annotated(annotated_grammar)

    mult = only(findall(==(true), annotated.label_domains["mult"]))
    consts = findall(==(true), annotated.label_domains["constants"])
    x,y = findall(==(true), annotated.label_domains["smallvars"])
    a,b,c = findall(==(true), annotated.label_domains["bigvars"])

    RN = check_constraints_module.HerbGrammar.RuleNode

    good = Vector{RN}()
    bad = Vector{RN}()

    # check for x<y<a all orders
    push!(good, RN(mult, [
        RN(mult, [
            RN(x), 
            RN(y)
        ]),
        RN(a)
    ]))
    push!(good, RN(mult, [
        RN(mult, [
            RN(y), 
            RN(a)
        ]),
        RN(x)
    ]))
    push!(bad, RN(mult, [
        RN(x), 
        RN(mult, [
            RN(y), 
            RN(a)
        ])
    ]))
    push!(bad, RN(mult, [
        RN(a), 
        RN(mult, [
            RN(x), 
            RN(y)
        ])
    ]))

    check_constraints_module.check_constraints(
        annotated.grammar,
        good,
        bad
    )
end
