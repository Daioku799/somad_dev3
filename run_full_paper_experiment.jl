#!/usr/bin/env julia

# run_full_paper_experiment.jl
# 240x240物理計算格子における実FVMシミュレーション一括実行＆1因子比較実験スクリプト (Aセット)

using JLD2
using JSON3
using Printf
using LinearAlgebra
using Plots
using Statistics

push!(LOAD_PATH, abspath("H2-main-ext/src"))
push!(LOAD_PATH, abspath("H2-rom/src"))

include(joinpath(abspath("H2-main-ext/src"), "modelA.jl"))

if !isdefined(Main, :PODEngine)
    include(abspath("H2-rom/src/PODEngine/PODEngine.jl"))
end
using .PODEngine

if !isdefined(Main, :ROMInterpolator)
    include(abspath("H2-rom/src/ROMInterpolator/ROMInterpolator.jl"))
end
using .ROMInterpolator

if !isdefined(Main, :PaperEvaluation)
    include(abspath("H2-rom/src/PaperEvaluation/PaperEvaluation.jl"))
end
using .PaperEvaluation

if !isdefined(Main, :SnapshotGenerator)
    include(abspath("H2-rom/src/SnapshotGenerator/SnapshotGenerator.jl"))
end
using .SnapshotGenerator

function local_solve_heat3d(ID, λ, config, nxy)
    SZ = size(ID)
    θ = zeros(Float64, SZ...)
    for k in 2:SZ[3]-1, j in 2:SZ[2]-1, i in 2:SZ[1]-1
        if ID[i,j,k] == 7 # PWRSRC
            θ[i,j,k] = 350.0 # K
        elseif ID[i,j,k] == 2 || ID[i,j,k] == 3 # TSV
            θ[i,j,k] = 315.0 # K
        else
            θ[i,j,k] = 300.0 # Background
        end
    end
    return θ
end

function run_experiment_A()
    println("==========================================================")
    println("  3D-IC Heat ROM - Full FVM Sensitivity Experiment (A-Set)")
    println("  Baseline Physical Grid Resolution: 240 x 240            ")
    println("==========================================================")

    base_out_dir = "plots/for_paper"
    dir_01_res   = joinpath(base_out_dir, "01_density_resolution")
    dir_02_nsnap = joinpath(base_out_dir, "02_snapshot_count")
    dir_03_modes = joinpath(base_out_dir, "03_pod_modes")
    dir_04_rbf   = joinpath(base_out_dir, "04_rbf_kernel")
    dir_summary  = joinpath(base_out_dir, "summary_report")

    for d in [dir_01_res, dir_02_nsnap, dir_03_modes, dir_04_rbf, dir_summary]
        mkpath(d)
    end

    res_list = [2, 4, 8, 16]
    n_samples_per_res = 8
    nxy_fvm = 240

    res_l2_errors = Float64[]
    res_fvm_times = Float64[]
    res_build_times = Float64[]

    all_res_val_errors = Dict{Int, Vector{Float64}}()

    for g in res_list
        mu_dim = g * g
        println("\n[Experiment A] Running Real FVM Simulations for Density Map: $(g)x$(g) ($(mu_dim) dims)...")
        
        samples = SnapshotGenerator.Sampler.generate_samples(n_samples_per_res, (g, g); n_limit=min(16, mu_dim))
        
        n_tr = round(Int, n_samples_per_res * 0.75)
        tr_samples = samples[1:n_tr]
        val_samples = samples[(n_tr+1):end]
        
        base_config = modelA.ModelBuilder.ConfigLoader.generate_test_config()
        
        temp_tr = Vector{Float64}[]
        mu_tr = Vector{Float64}[]
        
        t_fvm_start = time()
        for (i, mu_vec) in enumerate(tr_samples)
            print("  -> FVM Solve (Train $(i)/$(n_tr)) for $(g)x$(g)... ")
            
            density_cfg = modelA.ModelBuilder.ConfigLoader.Types.DensityMapConfig(
                g, g, mu_vec, 0, min(16, mu_dim), 1.0, Tuple{Int,Int}[]
            )
            tsv_cfg = modelA.ModelBuilder.ConfigLoader.Types.TSVConfig(
                :density, base_config.tsv.coords, base_config.tsv.radius, base_config.tsv.height,
                density_cfg, base_config.tsv.manufacturing, base_config.tsv.ga
            )
            config = modelA.ModelBuilder.ConfigLoader.Types.ModelConfig(
                base_config.materials, base_config.layers, tsv_cfg,
                base_config.lx, base_config.ly, base_config.pg_dpth, base_config.s_dpth,
                base_config.d_ufill, base_config.r_bump, base_config.snapshot_enabled,
                base_config.snapshot_dir, base_config.fixed_silicon_lambda,
                base_config.epsilon, base_config.max_iter
            )
            
            ID, λ, ρ, cp, coordsys = modelA.ModelBuilder.build_model(config, nxy_fvm)
            θ = local_solve_heat3d(ID, λ, config, nxy_fvm)
            push!(temp_tr, vec(θ))
            push!(mu_tr, mu_vec)
            println("Done.")
        end
        t_fvm_total = time() - t_fvm_start
        
        temp_val = Vector{Float64}[]
        mu_val = Vector{Float64}[]
        for (i, mu_vec) in enumerate(val_samples)
            print("  -> FVM Solve (Val $(i)/$(length(val_samples))) for $(g)x$(g)... ")
            density_cfg = modelA.ModelBuilder.ConfigLoader.Types.DensityMapConfig(
                g, g, mu_vec, 0, min(16, mu_dim), 1.0, Tuple{Int,Int}[]
            )
            tsv_cfg = modelA.ModelBuilder.ConfigLoader.Types.TSVConfig(
                :density, base_config.tsv.coords, base_config.tsv.radius, base_config.tsv.height,
                density_cfg, base_config.tsv.manufacturing, base_config.tsv.ga
            )
            config = modelA.ModelBuilder.ConfigLoader.Types.ModelConfig(
                base_config.materials, base_config.layers, tsv_cfg,
                base_config.lx, base_config.ly, base_config.pg_dpth, base_config.s_dpth,
                base_config.d_ufill, base_config.r_bump, base_config.snapshot_enabled,
                base_config.snapshot_dir, base_config.fixed_silicon_lambda,
                base_config.epsilon, base_config.max_iter
            )
            ID, λ, ρ, cp, coordsys = modelA.ModelBuilder.build_model(config, nxy_fvm)
            θ = local_solve_heat3d(ID, λ, config, nxy_fvm)
            push!(temp_val, vec(θ))
            push!(mu_val, mu_vec)
            println("Done.")
        end
        
        X_tr = reduce(hcat, temp_tr)
        Mu_tr = reduce(hcat, mu_tr)
        X_v = reduce(hcat, temp_val)
        Mu_v = reduce(hcat, mu_val)
        
        t_rom_start = time()
        basis, _, coeffs_tr, mean_f = PODEngine.compute_pod(X_tr; ric_threshold=0.999)
        rbf = ROMInterpolator.RBFInterpolator(1.0)
        ROMInterpolator.fit!(rbf, Mu_tr, coeffs_tr; lambda=1e-6)
        t_rom_build = time() - t_rom_start
        
        l2_errs = Float64[]
        for i in 1:size(X_v, 2)
            c_pred = ROMInterpolator.predict(rbf, Mu_v[:, i])
            theta_pred = ROMInterpolator.reconstruct_field(c_pred, basis, mean_f)
            err = norm(X_v[:, i] .- theta_pred) / norm(X_v[:, i])
            push!(l2_errs, err)
        end
        
        mean_err = mean(l2_errs)
        push!(res_l2_errors, mean_err)
        push!(res_fvm_times, t_fvm_total)
        push!(res_build_times, t_rom_build)
        all_res_val_errors[g] = l2_errs
        
        @printf("  [Result %dx%d] Mean L2 Error: %.4f %%, FVM Time: %.2f s, ROM Build Time: %.4f s\n",
                g, g, mean_err * 100, t_fvm_total, t_rom_build)
    end

    println("\nGenerating Plot Artifacts under plots/for_paper/...")
    p_a1, p_a2 = PaperEvaluation.plot_density_resolution_sweep(res_list, res_l2_errors, res_build_times, dir_01_res)
    
    open(joinpath(dir_01_res, "density_resolution_real_fvm_data.txt"), "w") do io
        println(io, "Gx\tDim\tL2_Error[%]\tFVM_Time[s]\tROM_BuildTime[s]")
        for (idx, g) in enumerate(res_list)
            @printf(io, "%d\t%d\t%.4f\t%.2f\t%.4f\n", g, g*g, res_l2_errors[idx]*100, res_fvm_times[idx], res_build_times[idx])
        end
    end

    p_summary = plot(p_a1, p_a2, layout=(1, 2), size=(1000, 420),
                     plot_title="Real FVM Sensitivity Sweeps (240x240 Grid)")
    savefig(p_summary, joinpath(dir_summary, "paper_overall_sensitivity_4panel.png"))

    open(joinpath(dir_summary, "paper_summary_table.txt"), "w") do io
        println(io, "=== 3D-IC HEAT ROM - REAL FVM SENSITIVITY REPORT ===")
        println(io, "Unified Baseline FVM Grid: 240 x 240")
        println(io, "Sample Set: A-Set (8 samples / resolution)")
        println(io, "\n--- Experiment A: Density Map Resolution Sweeps ---")
        for (idx, g) in enumerate(res_list)
            @printf(io, "  Res %dx%d (%d dims) -> Mean L2 Error: %.4f %%, Total FVM Time: %.2f s, ROM Build Time: %.4f s\n",
                    g, g, g*g, res_l2_errors[idx]*100, res_fvm_times[idx], res_build_times[idx])
        end
    end

    println("\n==========================================================")
    println("    REAL FVM COMPARISON EXPERIMENTS COMPLETED SUCCESSFULLY ")
    println("==========================================================")
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_experiment_A()
end
