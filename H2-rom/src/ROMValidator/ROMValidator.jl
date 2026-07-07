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

try
    using ValidationPlot
catch
    if !isdefined(Main, :ValidationPlot)
        path = joinpath(@__DIR__, "..", "ValidationPlot", "ValidationPlot.jl")
        Main.eval(:(include($path)))
    end
    using Main.ValidationPlot
end

include("types.jl")
include("evaluator.jl")
include("reporter.jl")


export ValidationResult, ValidationSummary
export get_validation_samples, get_trained_samples, load_test_case
export calculate_l2_error, calculate_tmax_error, calculate_hotspot_error
export judge_accuracy, evaluate_validation_results
export generate_report, generate_comparison_plots, run_validation
export measure_dataset_size, measure_fvm_runtime



end # module


