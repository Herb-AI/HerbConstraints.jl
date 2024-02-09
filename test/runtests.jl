using HerbConstraints
using Test

@testset "HerbConstraints.jl" verbose=true begin
    include("test_solver.jl")
    include("test_propagators.jl")
end

