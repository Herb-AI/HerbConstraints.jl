struct SolverStatistics
    dict::Dict{String, Int}
end

SolverStatistics() = SolverStatistics(Dict{String, Int}())

function track!(stats::SolverStatistics, key::String)
    if key ∈ keys(stats.dict)
        stats.dict[key] += 1
    else
        stats.dict[key] = 1
    end
end

function Base.show(io::IO, stats::SolverStatistics)
    println("SolverStatistics")
    max_key_length = maximum(length.(keys(stats.dict)))
    for (key, value) ∈ stats.dict
        spaces = "." ^ (max_key_length - length(key))
        println(io, "$key $spaces $value")
    end
end

function track!(::Nothing, key::String) end
