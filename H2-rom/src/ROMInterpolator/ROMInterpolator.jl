module ROMInterpolator

using LinearAlgebra
using JLD2

include("types.jl")
include("scaler.jl")
include("interpolator.jl")
include("reconstructor.jl")

export AbstractInterpolator, ScalingParams, RBFInterpolator, fit_scaler, scale_data, is_reliable
export compute_kernel_matrix, fit!, predict
export reconstruct_field

end # module
