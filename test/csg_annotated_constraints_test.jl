# """
# This test file tests that constraints in annotated grammars work as intended. 
# To make sure that constraints are tested properly:
#     * Each constraint should bad out at least one "bad" program uniquely
#     * At least one "good" program that is equivalent should pass all constraints
# Use "Run Tests with Coverage" to ensure that all constraints are covered by the tests.
# Make sure all tests have Total != 0 tests (that you did not forget to call the testing function).
# Recommended to tuRuleNode on notice_prints by default when developing tests.
# """
@testitem "csg annotated constraints" begin
    using HerbConstraints, HerbGrammar, Test
    
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

    @testset "identity" begin
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
        
        
        good = Vector{RuleNode}()
        bad = Vector{RuleNode}()

        # plus identity("zero")
        push!(good, RuleNode(x))
        push!(bad, RuleNode(plus, [
            RuleNode(x), 
            RuleNode(zero)
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(zero), 
            RuleNode(x)
        ]))

        # minus identity("zero")
        push!(good, RuleNode(x))
        push!(bad, RuleNode(minus, [RuleNode(zero)]))

        check_constraints(
            annotated.grammar,
            good,
            bad
        )
    end

    @testset "inverse" begin
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
        
        
        good = Vector{RuleNode}()
        bad = Vector{RuleNode}()

        # plus inverse("minus")
        push!(good, RuleNode(zero))
        push!(good, RuleNode(plus, [
            RuleNode(x), 
            RuleNode(minus, [RuleNode(y)])
        ]))
        push!(good, RuleNode(plus, [
            RuleNode(minus, [RuleNode(x)]),
            RuleNode(y)
        ]))

        push!(bad, RuleNode(plus, [
            RuleNode(x), 
            RuleNode(minus, [RuleNode(x)])
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(minus, [RuleNode(x)]),
            RuleNode(x)
        ]))

        push!(bad, RuleNode(minus, [
            RuleNode(minus, [
                RuleNode(y)
            ])
        ]))

        check_constraints(
            annotated.grammar,
            good,
            bad
        )
    end

    @testset "distributive_over" begin
        annotated_grammar = quote 
            var::       Number = x | y | z
            plus::      Number = Number + Number    
            times::     Number = Number * Number    := (distributive_over("plus"))
        end
        annotated = HerbConstraints.expr2csgrammar_annotated(annotated_grammar)
        x,y,z = findall(==(true), annotated.label_domains["var"])
        plus = only(findall(==(true), annotated.label_domains["plus"]))
        times = only(findall(==(true), annotated.label_domains["times"]))
        
        
        good = Vector{RuleNode}()
        bad = Vector{RuleNode}()

        # times distributive_over("plus")
        push!(good, RuleNode(times, [
            RuleNode(plus, [
                RuleNode(x),
                RuleNode(y)
            ]),
            RuleNode(z)
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(times, [
                RuleNode(x),
                RuleNode(z)
            ]),
            RuleNode(times, [
                RuleNode(y),
                RuleNode(z)
            ])
        ]))

        push!(good, RuleNode(times, [
            RuleNode(z),
            RuleNode(plus, [
                RuleNode(x),
                RuleNode(y)
            ])
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(times, [
                RuleNode(z),
                RuleNode(x)
            ]),
            RuleNode(times, [
                RuleNode(z),
                RuleNode(y)
            ])
        ]))

        push!(good, RuleNode(plus, [
            RuleNode(times, [
                RuleNode(x),
                RuleNode(z)
            ]),
            RuleNode(times, [
                RuleNode(z),
                RuleNode(y)
            ])
        ]))
        push!(good, RuleNode(plus, [
            RuleNode(times, [
                RuleNode(z),
                RuleNode(x)
            ]),
            RuleNode(times, [
                RuleNode(y),
                RuleNode(z)
            ])
        ]))

        push!(good, RuleNode(plus, [
            RuleNode(x),
            RuleNode(x)
        ]))

        check_constraints(
            annotated.grammar,
            good,
            bad
        )
    end

    @testset "distributive_over+commutative" begin
        annotated_grammar = quote 
            var::       Number = x | y | z
            plus::      Number = Number + Number    
            times::     Number = Number * Number    := (distributive_over("plus"), commutative)
        end
        annotated = HerbConstraints.expr2csgrammar_annotated(annotated_grammar)
        x,y,z = findall(==(true), annotated.label_domains["var"])
        plus = only(findall(==(true), annotated.label_domains["plus"]))
        times = only(findall(==(true), annotated.label_domains["times"]))
        
        good = Vector{RuleNode}()
        bad = Vector{RuleNode}()

        # times distributive_over("plus")
        push!(good, RuleNode(times, [
            RuleNode(z),
            RuleNode(plus, [
                RuleNode(x),
                RuleNode(y)
            ])
        ]))

        push!(bad, RuleNode(times, [
            RuleNode(plus, [
                RuleNode(x),
                RuleNode(y)
            ]),
            RuleNode(z)
        ]))

        push!(bad, RuleNode(plus, [
            RuleNode(times, [
                RuleNode(x),
                RuleNode(z)
            ]),
            RuleNode(times, [
                RuleNode(y),
                RuleNode(z)
            ])
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(times, [
                RuleNode(x),
                RuleNode(y)
            ]),
            RuleNode(times, [
                RuleNode(x),
                RuleNode(z)
            ])
        ]))

        push!(bad, RuleNode(plus, [
            RuleNode(times, [
                RuleNode(x),
                RuleNode(y)
            ]),
            RuleNode(times, [
                RuleNode(y),
                RuleNode(z)
            ])
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(times, [
                RuleNode(y),
                RuleNode(z)
            ]),
            RuleNode(times, [
                RuleNode(x),
                RuleNode(y)
            ])
        ]))

        push!(good, RuleNode(plus, [
            RuleNode(x),
            RuleNode(x)
        ]))

        check_constraints(
            annotated.grammar,
            good,
            bad
        )
    end

    @testset "associativity+commutative" begin
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


        

        good = Vector{RuleNode}()
        bad = Vector{RuleNode}()

        # basic ordering
        push!(good, RuleNode(plus, [
            RuleNode(consts[1]),
            RuleNode(plus, [
                RuleNode(consts[2]),
                RuleNode(plus, [
                    RuleNode(consts[3]), 
                    RuleNode(consts[4])
                ])
            ])
        ]))
        push!(good, RuleNode(plus, [
            RuleNode(consts[1]),
            RuleNode(plus, [
                RuleNode(consts[1]),
                RuleNode(plus, [
                    RuleNode(consts[1]), 
                    RuleNode(consts[1])
                ])
            ])
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(consts[3]), 
            RuleNode(consts[2])
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(b), 
            RuleNode(a)
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(b), 
            RuleNode(plus, [
                RuleNode(a), 
                RuleNode(b)
            ])
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(consts[3]), 
            RuleNode(plus, [
                RuleNode(consts[2]), 
                RuleNode(consts[3])
            ])
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(plus, [
                RuleNode(a), 
                RuleNode(b)
            ]),
            RuleNode(a)
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(plus, [
                RuleNode(consts[2]), 
                RuleNode(consts[3])
            ]),
            RuleNode(consts[2])
        ]))


        # permutations of x<y<plus<a<b<c
        push!(good, RuleNode(plus, [
            RuleNode(x), 
            RuleNode(plus, [
                RuleNode(y), 
                RuleNode(plus, [
                    RuleNode(plus, [
                        RuleNode(a), 
                        RuleNode(b)
                    ]),
                    RuleNode(c)
                ])
            ])
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(x), 
            RuleNode(plus, [
                RuleNode(plus, [
                    RuleNode(plus, [
                        RuleNode(y), 
                        RuleNode(a)
                    ]),
                    RuleNode(b)
                ]),
                RuleNode(c)
            ])
        ]))
        push!(bad, RuleNode(plus, [
            RuleNode(plus, [
                RuleNode(plus, [
                    RuleNode(plus, [
                        RuleNode(x), 
                        RuleNode(y)
                    ]),
                    RuleNode(a)
                ]),
                RuleNode(b)
            ]),
            RuleNode(c)
        ]))

        check_constraints(
            annotated.grammar,
            good,
            bad,
            # parallel plus will entail infinite depth - so we want the constraint but can't test it
            forgive_missing_constraints=true,
            notice_prints=false
        )
    end

    @testset "associativeity-commutative" begin
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

        good = Vector{RuleNode}()
        bad = Vector{RuleNode}()

        # check for x<y<a all orders
        push!(good, RuleNode(mult, [
            RuleNode(mult, [
                RuleNode(x), 
                RuleNode(y)
            ]),
            RuleNode(a)
        ]))
        push!(good, RuleNode(mult, [
            RuleNode(mult, [
                RuleNode(y), 
                RuleNode(a)
            ]),
            RuleNode(x)
        ]))
        push!(bad, RuleNode(mult, [
            RuleNode(x), 
            RuleNode(mult, [
                RuleNode(y), 
                RuleNode(a)
            ])
        ]))
        push!(bad, RuleNode(mult, [
            RuleNode(a), 
            RuleNode(mult, [
                RuleNode(x), 
                RuleNode(y)
            ])
        ]))

        check_constraints(
            annotated.grammar,
            good,
            bad
        )
    end
end