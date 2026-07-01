module ROMValidator

using Plots
using JLD2
using LinearAlgebra
using JSON3

try
    using ROMInterpolator
catch
    if !isdefined(Main, :ROMInterpolator)
        path = joinpath(@__DIR__, "..", "ROMInterpolator", "ROMInterpolator.jl")
        Main.eval(:(include($path)))
    end
    using Main.ROMInterpolator
end

include("types.jl")
include("evaluator.jl")
include("reporter.jl")


export ValidationResult, ValidationSummary
export get_validation_samples, load_test_case
export calculate_l2_error, calculate_tmax_error, calculate_hotspot_error
export judge_accuracy, evaluate_validation_results
export generate_report, generate_comparison_plots, run_validation


end # module


