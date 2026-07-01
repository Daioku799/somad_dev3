module ROMInterpolator

using LinearAlgebra
using JLD2

include("types.jl")
include("scaler.jl")

export AbstractInterpolator, ScalingParams, RBFInterpolator, fit_scaler, scale_data

end # module
