using HerbConstraints
using Test

@testset "HerbConstraints.jl" verbose=true begin
    include("test_domain_utils.jl")
    include("test_treemanipulations.jl")
    include("test_pattern_match.jl")
    include("test_lessthanorequal.jl")
    #include("test_pattern_match_edgecases.jl")
end
