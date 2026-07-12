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

struct OptimizationConfig
    n_pop::Int
    n_gen::Int
    cx_rate::Float64
    mut_rate::Float64
    n_elite::Int
end

function OptimizationConfig(ga_settings)
    return OptimizationConfig(
        ga_settings.n_pop,
        ga_settings.n_gen,
        ga_settings.cx_rate,
        ga_settings.mut_rate,
        ga_settings.n_elite
    )
end

