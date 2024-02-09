"""
    Solver

Maintains a feasible partial program in a [`State`](@ref). A [`ProgramIterator`](@ref) may manipulate the partial tree with the following functions:
- `remove`
- `substitute`
- `fill`
"""
mutable struct Solver
    grammar::Grammar
end


function is_subdomain(subdomain::BitVector, domain::BitVector)
    all(subdomain .| .!domain)
end


# function remove_rule!(s::Solver, hole::Hole, rule::Int)
#     hole.domain[rule] = 0
#     remaining_rule = findfirst(isequal(domain), 1) 
#     if all(isless, b, a)
    
# end


# fill!(s::Solver, hole::Hole, rule::Int)
