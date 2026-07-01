# types.jl - ROMInterpolator Types and Structures

abstract type AbstractInterpolator end

struct ScalingParams
    min_vals::Vector{Float64}
    max_vals::Vector{Float64}
end

struct RBFInterpolator <: AbstractInterpolator
    weights::Matrix{Float64}
    centers::Matrix{Float64}
    epsilon::Float64
    scaling_params::ScalingParams
    parameter_bounds::Matrix{Float64} # shape: 2 x N_dim (bounds for extrapolation detection)
end
