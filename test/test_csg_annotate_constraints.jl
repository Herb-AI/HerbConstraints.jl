using TestItems

#=
    TODO: change constraint testing format.
    Each constraint in the grammar should have:
    * a filtered case, that is filtered by that constraint only
    * an equivalent unfiltered case, that is allowed by all constraints
    Also, make sure all constraints that can be in a grammar are tested.
    For example all combinations of associative, commutative, distributive_over
    Use test coverage tools to ensure.
=#

@testmodule check_constraints_module begin
    using HerbConstraints
    using HerbGrammar
    using Test

    function check_constraints(
        annotated_grammar::ContextSensitiveGrammar,
        good_programs::Vector{RuleNode},
        bad_programs::Vector{RuleNode},
    )
        for p ∈ good_programs
            # println("Checking good program: ", HerbGrammar.rulenode2expr(p, annotated_grammar))
            for c ∈ annotated_grammar.constraints
                if !((@test HerbConstraints.check_tree(c, p)) isa Test.Pass)
                    println()
                    println("Fail information:")
                    println("$(HerbGrammar.rulenode2expr(p, annotated_grammar)) was filtered by constraint:")
                    println(c)
                    println()
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
            if length(constrained_by) > 1
                println()
                println("Notice:")
                println("$(HerbGrammar.rulenode2expr(p, annotated_grammar)) was filtered by multiple constraints")
                [println(c) for c in constrained_by]
            elseif length(constrained_by) == 1
                push!(tested_constraints, constrained_by[1])
            elseif length(constrained_by) == 0
                println("Fail information:")
                println("$(HerbGrammar.rulenode2expr(p, annotated_grammar)) was not filtered by any constraint")
            end
        end
        if !((@test length(tested_constraints) == length(annotated_grammar.constraints)) isa Test.Pass)
            println()
            println("Fail information:")
            println("Not all constraints were tested.")
            # println("Tested constraints:")
            # [println(c) for c in tested_constraints]
            # println("All constraints:")
            # [println(c) for c in annotated_grammar.constraints]
            println("Missing constraints:")
            [println(c) for c in setdiff(Set(annotated_grammar.constraints), tested_constraints)]
            println()
        end
    end
end

@testitem "constraints: associativity+commutative" setup=[check_constraints_module] begin
    num_annotated = quote        
        constants:: Number = |(1:4) 
        variables:: Number = x | y 
        plus::      Number = Number + Number    := (associative, commutative)
        variables:: Number = a | b | c
    end
    annotated = HerbConstraints.expr2csgrammar_annotated(num_annotated)
  
    plus = only(findall(==(true), annotated.label_domains["plus"]))
    consts = findall(==(true), annotated.label_domains["constants"])
    smallvars = findall(==(true), annotated.label_domains["variables"])
    x = smallvars[1]
    y = smallvars[2]
    numrules = length(GrammarExpr.annotated.grammar.rules)
    bigvars = (numrules - 2) : numrules
    a = bigvars[1]
    b = bigvars[2]
    c = bigvars[3]


    rn = check_constraints_module.HerbGrammar.RuleNode

    good = Vector{HerbGrammar.RuleNode}()
    filter = Vector{HerbGrammar.RuleNode}()

    # minus :identity("zero")
    push!(good, rn(zero))
    push!(filter, rn(minus, [rn(zero)]))

    # plus associative + commutative
    # permutations of x<y<plus<a<b<c
    push!(good, rn(plus, [
        rn(x), 
        rn(plus, [
            rn(y), 
            rn(plus, [
                rn(plus, [
                    rn(a), 
                    rn(b)
                ]),
                rn(c)
            ])
        ])
    ]))
    push!(filter, rn(plus, [
        rn(x), 
        rn(plus, [
            rn(plus, [
                rn(plus, [
                    rn(y), 
                    rn(a)
                ]),
                rn(b)
            ]),
            rn(c)
        ])
    ]))
    push!(filter, rn(plus, [
        rn(plus, [
            rn(plus, [
                rn(plus, [
                    rn(x), 
                    rn(y)
                ]),
                rn(a)
            ]),
            rn(b)
        ]),
        rn(c)
    ]))
    push!(good, rn(plus, [
        rn(consts[1]),
        rn(plus, [
            rn(consts[2]),
            rn(plus, [
                rn(consts[3]), 
                rn(consts[4])
            ])
        ])
    ]))
    push!(good, rn(plus, [
        rn(consts[1]),
        rn(plus, [
            rn(consts[1]),
            rn(plus, [
                rn(consts[1]), 
                rn(consts[1])
            ])
        ])
    ]))
    push!(filter, rn(plus, [
        rn(consts[3]), 
        rn(consts[2])
    ]))
    push!(filter, rn(plus, [
        rn(b), 
        rn(a)
    ]))
    push!(filter, rn(plus, [
        rn(b), 
        rn(plus, [
            rn(a), 
            rn(b)
        ])
    ]))
    push!(filter, rn(plus, [
        rn(consts[3]), 
        rn(plus, [
            rn(consts[2]), 
            rn(consts[3])
        ])
    ]))
    push!(filter, rn(plus, [
        rn(plus, [
            rn(a), 
            rn(b)
        ]),
        rn(a)
    ]))
    push!(filter, rn(plus, [
        rn(plus, [
            rn(consts[2]), 
            rn(consts[3])
        ]),
        rn(consts[2])
    ]))

    # plus identity("zero")
    push!(good, rn(x))
    push!(filter, rn(plus, [
        rn(x), 
        rn(zero)
    ]))
    push!(filter, rn(plus, [
        rn(zero), 
        rn(x)
    ]))

    # plus inverse("minus")
    push!(good, rn(zero))
    push!(good, rn(plus, [
        rn(x), 
        rn(minus, [rn(y)])
    ]))
    push!(good, rn(plus, [
        rn(y), 
        rn(minus, [rn(x)])
    ]))
    push!(good, rn(plus, [
        rn(minus, [rn(x)]),
        rn(a)
    ]))
    push!(filter, rn(plus, [
        rn(x), 
        rn(minus, [rn(x)])
    ]))
    push!(filter, rn(plus, [
        rn(minus, [rn(x)]),
        rn(x)
    ]))

    # times associative


    # # times associative + commutative
    # filtered("x * (2y)")
    # filtered("y * (2x)")
    
    # # times commutative
    # in_both("4y")
    # filtered("y * 4")

    # # times identity("one")
    # in_both("x")
    # filtered("1x")
    
    # # times distributive_over("plus")
    # in_both("2 * (x + y)")
    # filtered("2x + 2y")
    # filtered("2x + 3x")

    # # times distributive_over("plus") + plus commutative
    # filtered("2 * 3 + 3x")
    # filtered("3x + x * y")

    check_constraints_module.check_constraints(
        GrammarExpr.annotated.grammar,
        good,
        filter,
    )
end

