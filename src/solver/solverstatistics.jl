"""
Temporary struct to `track!` the number of several function calls centered around the [`Solver`](@ref)
"""
mutable struct SolverStatistics
    name::String
    dict::Dict{String, Int}
end

SolverStatistics(name::String) = SolverStatistics(name, Dict{String, Int}())

function track!(stats::SolverStatistics, key::String)
    key = "[$(stats.name)] $(key)"
    if key ∈ keys(stats.dict)
        stats.dict[key] += 1
    else
        stats.dict[key] = 1
    end
end

function Base.show(io::IO, stats::SolverStatistics)
    print(io, "SolverStatistics: \n")
    if length(keys(stats.dict)) > 0
        max_key_length = maximum(length.(keys(stats.dict)))
        for key ∈ sort(collect(keys(stats.dict))) #keys(stats.dict)
            spaces = "." ^ (max_key_length - length(key))
            print(io, "$key $spaces $(stats.dict[key])\n")
        end
    else
        print(io, "...nothing...\n")
    end
end

function track!(::Nothing, key::String) end
