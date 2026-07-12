# Types.jl - Data structures for the genetic algorithm optimizer

mutable struct Individual
    mu::Vector{Float64}
    fitness::Float64
    is_fvm_verified::Bool
    extrapolation_score::Float64
end

# Convenient constructors for Individual
function Individual(mu::Vector{Float64})
    return Individual(mu, Inf, false, 0.0)
end

function Individual(mu::Vector{Float64}, fitness::Float64)
    return Individual(mu, fitness, false, 0.0)
end

mutable struct OptimizationState
    generation::Int
    best_individual::Union{Nothing, Individual}
    population::Vector{Individual}
    history::Vector{Float64}
end

# Convenient constructors for OptimizationState
function OptimizationState(population::Vector{Individual})
    return OptimizationState(0, nothing, population, Float64[])
end
