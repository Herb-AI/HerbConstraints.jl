using HerbConstraints
using Test

@testset "HerbConstraints.jl" verbose=true begin
    include("test_domain_utils.jl")
    include("test_treemanipulations.jl")
    include("test_varnode.jl")
    include("test_pattern_match.jl")
    include("test_pattern_match_domainrulenode.jl")
    #include("test_pattern_match_edgecases.jl")
    include("test_lessthanorequal.jl")
    include("test_forbidden.jl")
    include("test_ordered.jl")

    include("test_state_sparse_set.jl")
    include("test_state_manager.jl")

    include("test_fixed_shaped_solver.jl")
    include("test_state_fixed_shaped_hole.jl")
end
