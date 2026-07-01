module ROMValidator

using Plots
using JLD2
using LinearAlgebra
using JSON3

include("types.jl")
include("evaluator.jl")

export ValidationResult, ValidationSummary
export get_validation_samples, load_test_case
export calculate_l2_error, calculate_tmax_error, calculate_hotspot_error


end # module
