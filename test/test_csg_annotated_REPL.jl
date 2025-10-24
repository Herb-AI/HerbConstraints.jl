using HerbConstraints
using HerbGrammar
using HerbSearch
using HerbCore

# csgrammar
begin
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
    @assert length(grammar.constraints)==0

    grammar_candidates = Vector{String}()
    for (i, candidate_program) ∈ enumerate(HerbSearch.BFSIterator(grammar, :Number, max_depth=3))
        push!(grammar_candidates, "$(HerbGrammar.rulenode2expr(candidate_program, grammar))")
    end
end

# annotated grammar
begin
    num_annotated = quote   
        variables:: Number = x | y      
        zero::  Number = 0             
        one::  Number = 1     
        constants:: Number = |(2:4)              
        minus::      Number = -Number           := (identity("zero"))
        plus::      Number = Number + Number    := (associative, commutative, identity("zero"), inverse("minus"))
        times::     Number = Number * Number    := (associative, commutative, identity("one"), distributive_over("plus"))
    end
    annotated = HerbConstraints.expr2csgrammar_annotated(num_annotated)
    @assert length(annotated.grammar.constraints) == 18

    annotated_candidates = Vector{String}()
    for candidate_program ∈ HerbSearch.BFSIterator(annotated.grammar, :Number, max_depth=3)
        push!(annotated_candidates, "$(HerbGrammar.rulenode2expr(candidate_program, annotated.grammar))")
    end
end

println(length(annotated_candidates))
println(length(grammar_candidates))

# get bad programs
begin
    bad_programs = Vector{Any}()
    for candidate_program ∈ HerbSearch.BFSIterator(grammar, :Number, max_depth=2)
        if candidate_program ∉ iterator
            println("$(HerbGrammar.rulenode2expr(candidate_program, grammar))")
        end
    end

    # check spesific program
    begin
        rulenode = HerbCore.@rulenode 8{3}
        println("Candidate program: $(HerbGrammar.rulenode2expr(rulenode, annotated.grammar))")
        constraints = annotated.grammar.constraints
        for c in constraints
            try
                if check_tree(c, rulenode)
                    println("\tpass: $c")
                else
                    println("Fail: $c")
                end
            catch e
                println("Error checking constraint $c:\n $e")
            end
        end
    end
end




    begin
        # rulenode_programs = Set([rand(RuleNode, annotated.grammar, :Number, 8) for _ in 1:50])
        # println(" rules = Vector{RuleNode}()")
        # for program in rulenode_programs
        #     println("push!(rules, HerbCore.@rulenode $program)")
        # end

        # rules = Vector{RuleNode}()
        # push!(rules, HerbCore.@rulenode 5)
        # push!(rules, HerbCore.@rulenode 10{7,10{4,7}})
        # push!(rules, HerbCore.@rulenode 8{7})
        # push!(rules, HerbCore.@rulenode 6)
        # push!(rules, HerbCore.@rulenode 10{6,4})
        # push!(rules, HerbCore.@rulenode 9{10{6,1},2})
        # push!(rules, HerbCore.@rulenode 4)
        # push!(rules, HerbCore.@rulenode 10{8{4},5})
        # push!(rules, HerbCore.@rulenode 10{6,3})
        # push!(rules, HerbCore.@rulenode 8{9{10{3,10{1,9{3,7}}},8{9{3,3}}}})
        # push!(rules, HerbCore.@rulenode 9{4,8{3}})
        # push!(rules, HerbCore.@rulenode 8{10{6,1}})
        # push!(rules, HerbCore.@rulenode 1)
        # push!(rules, HerbCore.@rulenode 8{9{2,10{7,5}}})
        # push!(rules, HerbCore.@rulenode 3)
        # push!(rules, HerbCore.@rulenode 7)
        # push!(rules, HerbCore.@rulenode 10{1,4})
        # push!(rules, HerbCore.@rulenode 9{3,8{2}})
        # push!(rules, HerbCore.@rulenode 2)
        # push!(rules, HerbCore.@rulenode 9{10{3,7},9{2,10{1,2}}})
        # for program in rules
        #     println("Generated program: $(HerbGrammar.rulenode2expr(program, annotated.grammar))")
        # end





        # g = HerbGrammar.@csgrammar begin
        #     Number = 0|2|4|6|8
        #     Number = x
        #     Number = Number + Number
        #     Number = Number - Number
        #     Number = Number * Number
        # end
        # iterator_1 = HerbSearch.BFSIterator(g, :Number, max_depth=5)
        # Iterators.dropwhile(t -> contains_index(7, t), Iterators.drop(iterator_1, 10))

        # for (i, candidate_program) ∈ enumerate(iterator_1)
        #     println("Found program with multiplication at position $i: $(expr = rulenode2expr(candidate_program, g))")
        #     # if contains_index(7, candidate_program)
        #         break 
        #     # end
        # end

        # annotated = HerbConstraints.expr2csgrammar_annotated(num_annotated)
        # sample_steps = [0, 10, 50, 100, 500, 1000, 5000, 10000]

        # plus_rule = only(findall(==(true), annotated.label_domains["plus"]))
        
        # annotated.grammar

        # plus_iterator = HerbSearch.BFSIterator(annotated.grammar, :Number)
        # for (i, candidate_program) ∈ enumerate(plus_iterator)
        #     println("Found program with plus at position $i: $(HerbGrammar.rulenode2expr(candidate_program))")
        # end


        # plus_iterator = Iterators.dropwhile(t -> contains_index(plus_rule, t), Iterators.drop(plus_iterator, 10))
        
        # tree = collect(enumerate(plus_iterator))
        # println("After $steps steps, found tree with plus: $(HerbSearch.tree_to_expr(tree))")

        # for steps in sample_steps
        #     plus_iterator = Iterators.dropwhile(t -> contains_index(plus_rule, t), Iterators.drop(plus_iterator, steps))
        #     tree = first(plus_iterator)
        #     println("After $steps steps, found tree with plus: $(HerbSearch.tree_to_expr(tree))")
        # end



        # times_rule = only(findall(==(true), annotated.label_domains["times"]))
        # times_annotations = annotated.rule_annotations[times_rule]
        # @test :(commutative) in times_annotations
    end
    

    rule_index = 1
    label_index = 2

    num_label_children = 0
    label_children = [VarNode(Symbol("y_$(i)")) for i in 1:num_label_children]
    label_node = RuleNode(label_index, label_children)

    num_rule_children = 1
    rule_children = [VarNode(Symbol("x_$(i)")) for i in 1:num_rule_children]
    RuleNode(rule_index, rule_children)
    rule_non_label_children = [VarNode(Symbol("x_$(i)")) for i in 1:num_rule_children-1]
    for i in 1:num_rule_children
        rule_children = Vector{AbstractRuleNode}(copy(rule_non_label_children))
        insert!(rule_children, i,label_node)
        println(rule_children)
        println(RuleNode(rule_index, rule_children))
        println(Forbidden(RuleNode(rule_index, rule_children)))
    end