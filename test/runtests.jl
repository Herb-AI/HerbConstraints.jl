using HerbConstraints
using Test

@testset "HerbConstraints.jl" verbose=true begin
    include("test_domain_utils.jl")
    include("test_treemanipulations.jl")
    include("test_pattern_match.jl")
    #include("test_propagators.jl")
end
