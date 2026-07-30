#!/usr/bin/env julia

# generate_50_snapshots.jl
# 統一60x60x30物理格子による50ケース全自動スナップショット生成および感度解析スクリプト

push!(LOAD_PATH, abspath("H2-main-ext/src"))
push!(LOAD_PATH, abspath("H2-rom/src"))

if !isdefined(Main, :SnapshotGenerator)
    include(abspath("H2-rom/src/SnapshotGenerator/SnapshotGenerator.jl"))
end
using .SnapshotGenerator

println("==========================================================")
println(" Step 1: Generating 50 Unified Snapshots (Grid: 60x60x30) ")
println("==========================================================")

run_generator(50; solver_dir="H2-main-ext", data_dir="data")

println("\n==========================================================")
println(" Step 2: Re-running Sensitivity Sweeps & Paper Evaluation ")
println("==========================================================")

include("evaluate_rom_paper_sweeps.jl")
main_sweeps()

println("\n==========================================================")
println("        ALL 50-SNAPSHOT EXPERIMENTS COMPLETED SUCCESS     ")
println("==========================================================")
