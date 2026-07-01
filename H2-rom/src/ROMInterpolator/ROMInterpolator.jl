module ROMInterpolator

using LinearAlgebra
using JLD2

include("types.jl")
include("scaler.jl")
include("interpolator.jl")

export AbstractInterpolator, ScalingParams, RBFInterpolator, fit_scaler, scale_data
export compute_kernel_matrix

end # module
