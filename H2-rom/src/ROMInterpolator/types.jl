# types.jl - ROMInterpolator Types and Structures

abstract type AbstractInterpolator end

struct ScalingParams
    min_vals::Vector{Float64}
    max_vals::Vector{Float64}
end

mutable struct RBFInterpolator <: AbstractInterpolator
    weights::Matrix{Float64}
    centers::Matrix{Float64}
    epsilon::Float64
    scaling_params::ScalingParams
    parameter_bounds::Matrix{Float64} # shape: 2 x N_dim (bounds for extrapolation detection)

    function RBFInterpolator(epsilon::Float64)
        new(
            Matrix{Float64}(undef, 0, 0),
            Matrix{Float64}(undef, 0, 0),
            epsilon,
            ScalingParams(Float64[], Float64[]),
            Matrix{Float64}(undef, 0, 0)
        )
    end

    function RBFInterpolator(weights::Matrix{Float64}, centers::Matrix{Float64}, epsilon::Float64, scaling_params::ScalingParams, parameter_bounds::Matrix{Float64})
        new(weights, centers, epsilon, scaling_params, parameter_bounds)
    end
end

