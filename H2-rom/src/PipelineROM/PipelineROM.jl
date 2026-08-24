"""
    PipelineROM

縮約モデルの構築・予測・精度評価・保存のみを所有する。
分割の決定はしない（呼び出し側が添字で渡す）。run 固有のパスも条件も持たない。

POD 分解と RBF 補間のアルゴリズムは既存の `PODEngine` / `ROMInterpolator` が
所有し、本モジュールはそれを呼び出すのみ（契約は変更しない）。
"""
module PipelineROM

using JLD2
using LinearAlgebra
using Statistics

include(joinpath(@__DIR__, "..", "PODEngine", "PODEngine.jl"))
using .PODEngine
include(joinpath(@__DIR__, "..", "ROMInterpolator", "ROMInterpolator.jl"))
using .ROMInterpolator

include("types.jl")
include("builder.jl")

export RomSettings, RomModel, AccuracyReport, RomBuildError
export build_rom, select_settings, predict_field, predict_tmax
export evaluate_accuracy, save_rom, load_rom, pod_spectrum
export hot_row_indices, TmaxEvaluator, tmax_evaluator

end # module
