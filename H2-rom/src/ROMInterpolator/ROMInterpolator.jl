module ROMInterpolator

using LinearAlgebra
using JLD2

include("types.jl")

export AbstractInterpolator, ScalingParams, RBFInterpolator

end # module
