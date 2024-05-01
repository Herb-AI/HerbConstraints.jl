"""
Temporary struct to `track!` the number of several function calls centered around the [`Solver`](@ref)
"""
struct SolverStatistics
    dict::Dict{String, Int}
end

SolverStatistics() = SolverStatistics(Dict{String, Int}())

function track!(solver::Solver, key::String)
    if !isnothing(solver.statistics)
        key = "[$(get_name(solver))] $key"
        track!(solver.statistics, key)
    end
end

function track!(statistics::SolverStatistics, key::String)
    if key ∈ keys(statistics.dict)
        statistics.dict[key] += 1
    else
        statistics.dict[key] = 1
    end
end

function Base.show(io::IO, statistics::SolverStatistics)
    print(io, "SolverStatistics: \n")
    if length(keys(statistics.dict)) > 0
        max_key_length = maximum(length.(keys(statistics.dict)))
        for key ∈ sort(collect(keys(statistics.dict))) #keys(statistics.dict)
            spaces = "." ^ (max_key_length - length(key))
            print(io, "$key $spaces $(statistics.dict[key])\n")
        end
    else
        print(io, "...nothing...\n")
    end
end

function track!(::Nothing, key::String) end
