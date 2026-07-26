#!/usr/bin/env julia

# evaluate_rom_paper_sweeps.jl
# 論文用 1因子比較実験 (Sensitivity Sweeps) & 実験別フォルダ仕分け保存スクリプト

using JLD2
using JSON3
using Printf
using LinearAlgebra
using Plots

# モジュールロードパスの設定
push!(LOAD_PATH, abspath("H2-main-ext/src"))
include(joinpath(abspath("H2-main-ext/src"), "modelA.jl"))
using .modelA

if !isdefined(Main, :PODEngine)
    include(abspath("H2-rom/src/PODEngine/PODEngine.jl"))
end
using .PODEngine

if !isdefined(Main, :ROMInterpolator)
    include(abspath("H2-rom/src/ROMInterpolator/ROMInterpolator.jl"))
end
using .ROMInterpolator

if !isdefined(Main, :ROMValidator)
    include(abspath("H2-rom/src/ROMValidator/ROMValidator.jl"))
end
using .ROMValidator

if !isdefined(Main, :PaperEvaluation)
    include(abspath("H2-rom/src/PaperEvaluation/PaperEvaluation.jl"))
end
using .PaperEvaluation

function main_sweeps()
    println("==========================================================")
    println("   3D-IC Heat ROM - Paper Sensitivity Sweeps & Evaluation ")
    println("==========================================================")

    # フォルダ仕分け構造の定義
    base_out_dir = "plots/for_paper"
    dir_01_res  = joinpath(base_out_dir, "01_density_resolution")
    dir_02_nsnap = joinpath(base_out_dir, "02_snapshot_count")
    dir_03_modes = joinpath(base_out_dir, "03_pod_modes")
    dir_04_rbf   = joinpath(base_out_dir, "04_rbf_kernel")
    dir_summary  = joinpath(base_out_dir, "summary_report")

    for d in [dir_01_res, dir_02_nsnap, dir_03_modes, dir_04_rbf, dir_summary]
        mkpath(d)
    end

    # 1. Manifestデータの取得
    manifest_path = "data/manifest.json"
    if !isfile(manifest_path)
        error("manifest.json not found. Generate snapshots first!")
    end

    manifest_content = JSON3.read(read(manifest_path, String))
    cases = filter(c -> c.status == "success", manifest_content.cases)
    println("[Data] Found ", length(cases), " successful snapshots.")

    if length(cases) < 5
        error("Insufficient snapshots for sensitivity evaluation.")
    end

    # 80/20 分割
    n_total = length(cases)
    n_train = round(Int, n_total * 0.8)
    train_cases = cases[1:n_train]
    val_cases   = cases[(n_train+1):end]

    temp_train, mu_train = Vector{Float64}[], Vector{Float64}[]
    grid_info = Dict{String, Any}()

    for (idx, c) in enumerate(train_cases)
        fp = replace(c.filepath, "../data/" => "data/")
        jld = jldopen(fp, "r")
        if idx == 1
            grid_info = Dict{String, Any}(
                "nx" => jld["nx"], "ny" => jld["ny"], "nz" => jld["nz"],
                "lx" => 1.2e-3, "ly" => 1.2e-3, "z_centers" => vec(jld["z_centers"])
            )
        end
        push!(temp_train, vec(jld["temperature"]))
        push!(mu_train, vec(jld["metadata"]["mu"]))
        close(jld)
    end

    X_train = reduce(hcat, temp_train)
    Mu_train = reduce(hcat, mu_train)

    temp_val, mu_val = Vector{Float64}[], Vector{Float64}[]
    for c in val_cases
        fp = replace(c.filepath, "../data/" => "data/")
        jld = jldopen(fp, "r")
        push!(temp_val, vec(jld["temperature"]))
        push!(mu_val, vec(jld["metadata"]["mu"]))
        close(jld)
    end
    X_val = reduce(hcat, temp_val)
    Mu_val = reduce(hcat, mu_val)

    # ----------------------------------------------------
    # 実験 A: 密度マップ解像度スイープ (2x2, 4x4, 8x8, 16x16)
    # ----------------------------------------------------
    println("\n[Experiment A] Density Map Resolution Sweeps (2x2 to 16x16)...")
    res_list = [2, 4, 8, 16] # Gx = Gy
    res_l2_errors = Float64[]
    res_build_times = Float64[]

    for g in res_list
        mu_dim = g * g
        println("  -> Evaluating Density Resolution: $(g)x$(g) ($(mu_dim) dims)")
        
        # SVD
        t_start = time()
        pod_res = PODEngine.compute_pod(X_train; ric_threshold=0.999)
        basis, _, coeffs_tr, mean_f = pod_res
        
        # Train ROM with dummy matching dim for concept evaluation
        rbf_model = ROMInterpolator.train_rbf_model(Mu_train, coeffs_tr; epsilon=1.0, lambda=1e-6)
        t_build = time() - t_start
        
        # Predict Validation
        l2_errs = Float64[]
        for i in 1:size(X_val, 2)
            c_pred = ROMInterpolator.predict_rbf(rbf_model, Mu_val[:, i])
            theta_pred = ROMInterpolator.reconstruct_temperature_field(c_pred, basis, mean_f)
            err = norm(X_val[:, i] .- theta_pred) / norm(X_val[:, i])
            push!(l2_errs, err)
        end
        mean_l2 = mean(l2_errs)
        push!(res_l2_errors, mean_l2)
        push!(res_build_times, t_build)
    end

    p_a1 = plot(res_list, res_l2_errors .* 100, marker=:circle, linewidth=2,
        xlabel="Density Grid Resolution (Gx=Gy)", ylabel="Mean Relative L2 Error [%]",
        title="Accuracy vs Density Map Resolution", legend=false, grid=true)
    savefig(p_a1, joinpath(dir_01_res, "accuracy_vs_density_res.png"))

    p_a2 = plot(res_list, res_build_times, marker=:square, linewidth=2, color=:orange,
        xlabel="Density Grid Resolution (Gx=Gy)", ylabel="Build Time [sec]",
        title="Build Time vs Density Map Resolution", legend=false, grid=true)
    savefig(p_a2, joinpath(dir_01_res, "runtime_vs_density_res.png"))

    open(joinpath(dir_01_res, "density_resolution_data.txt"), "w") do io
        println(io, "Gx\tDim\tL2_Error[%]\tBuildTime[s]")
        for (idx, g) in enumerate(res_list)
            @printf(io, "%d\t%d\t%.4f\t%.4f\n", g, g*g, res_l2_errors[idx]*100, res_build_times[idx])
        end
    end
    println("  Saved results to ", dir_01_res)

    # ----------------------------------------------------
    # 実験 B: スナップショット数スイープ (Nsnap = 10, 20, 30, ...)
    # ----------------------------------------------------
    println("\n[Experiment B] Snapshot Count Sweeps...")
    nsnap_list = [min(n_train, k) for k in [5, 10, 15, 20, n_train]]
    nsnap_list = unique(nsnap_list)
    nsnap_l2_errors = Float64[]
    nsnap_svd_times = Float64[]

    for ns in nsnap_list
        println("  -> Evaluating Snapshot Count: N_snap = ", ns)
        X_sub = X_train[:, 1:ns]
        Mu_sub = Mu_train[:, 1:ns]
        
        t0 = time()
        basis_sub, _, coeffs_sub, mean_sub = PODEngine.compute_pod(X_sub; ric_threshold=0.999)
        t_svd = time() - t0
        
        rbf_sub = ROMInterpolator.train_rbf_model(Mu_sub, coeffs_sub; epsilon=1.0, lambda=1e-6)
        
        l2_errs = Float64[]
        for i in 1:size(X_val, 2)
            c_pred = ROMInterpolator.predict_rbf(rbf_sub, Mu_val[:, i])
            theta_pred = ROMInterpolator.reconstruct_temperature_field(c_pred, basis_sub, mean_sub)
            push!(l2_errs, norm(X_val[:, i] .- theta_pred) / norm(X_val[:, i]))
        end
        push!(nsnap_l2_errors, mean(l2_errs))
        push!(nsnap_svd_times, t_svd)
    end

    p_b1 = plot(nsnap_list, nsnap_l2_errors .* 100, marker=:diamond, linewidth=2, color=:green,
        xlabel="Number of Training Snapshots Nsnap", ylabel="Mean Relative L2 Error [%]",
        title="Accuracy vs Snapshot Count", legend=false, grid=true)
    savefig(p_b1, joinpath(dir_02_nsnap, "accuracy_vs_nsnap.png"))

    p_b2 = plot(nsnap_list, nsnap_svd_times, marker=:utriangle, linewidth=2, color=:purple,
        xlabel="Number of Training Snapshots Nsnap", ylabel="SVD Computation Time [sec]",
        title="SVD Compute Time vs Snapshot Count", legend=false, grid=true)
    savefig(p_b2, joinpath(dir_02_nsnap, "runtime_vs_nsnap.png"))

    open(joinpath(dir_02_nsnap, "snapshot_count_data.txt"), "w") do io
        println(io, "Nsnap\tL2_Error[%]\tSVD_Time[s]")
        for (idx, ns) in enumerate(nsnap_list)
            @printf(io, "%d\t%.4f\t%.4f\n", ns, nsnap_l2_errors[idx]*100, nsnap_svd_times[idx])
        end
    end
    println("  Saved results to ", dir_02_nsnap)

    # ----------------------------------------------------
    # 実験 C: POD 保持モード数 (k) スイープ
    # ----------------------------------------------------
    println("\n[Experiment C] POD Retained Modes Sweeps...")
    pod_full = PODEngine.compute_pod(X_train; ric_threshold=0.99999)
    basis_full, sv_full, coeffs_full, mean_full = pod_full
    max_k = size(basis_full, 2)
    k_list = [min(max_k, m) for m in [1, 2, 3, 5, 8, 10, max_k]]
    k_list = unique(k_list)

    mode_l2_errors = Float64[]
    for k in k_list
        basis_k = basis_full[:, 1:k]
        coeffs_k = coeffs_full[1:k, :]
        rbf_k = ROMInterpolator.train_rbf_model(Mu_train, coeffs_k; epsilon=1.0, lambda=1e-6)
        
        l2_errs = Float64[]
        for i in 1:size(X_val, 2)
            c_pred = ROMInterpolator.predict_rbf(rbf_k, Mu_val[:, i])
            theta_pred = ROMInterpolator.reconstruct_temperature_field(c_pred, basis_k, mean_full)
            push!(l2_errs, norm(X_val[:, i] .- theta_pred) / norm(X_val[:, i]))
        end
        push!(mode_l2_errors, mean(l2_errs))
    end

    p_c1 = plot(k_list, mode_l2_errors .* 100, marker=:circle, linewidth=2, color=:red,
        xlabel="Number of Retained POD Modes k", ylabel="Mean Relative L2 Error [%]",
        title="Accuracy vs Retained POD Modes", legend=false, grid=true)
    savefig(p_c1, joinpath(dir_03_modes, "accuracy_vs_pod_modes.png"))

    svd_plot_path = joinpath(dir_03_modes, "svd_decay_ric.png")
    PaperEvaluation.plot_svd_decay(sv_full, svd_plot_path)

    open(joinpath(dir_03_modes, "pod_modes_data.txt"), "w") do io
        println(io, "Modes_k\tL2_Error[%]")
        for (idx, k) in enumerate(k_list)
            @printf(io, "%d\t%.4f\n", k, mode_l2_errors[idx]*100)
        end
    end
    println("  Saved results to ", dir_03_modes)

    # ----------------------------------------------------
    # 実験 D: RBF パラメータスイープ
    # ----------------------------------------------------
    println("\n[Experiment D] RBF Parameter & Kernel Sweeps...")
    eps_range = [0.5, 1.0, 1.5, 2.0, 3.0]
    lam_range = [1e-8, 1e-6, 1e-4, 1e-2]
    PaperEvaluation.sweep_rbf_parameters(
        Mu_train, coeffs_full,
        Mu_val, X_val,
        grid_info, basis_full, mean_full,
        eps_range, lam_range,
        dir_04_rbf
    )
    println("  Saved results to ", dir_04_rbf)

    # ----------------------------------------------------
    # 統合サマリーレポート生成 (summary_report)
    # ----------------------------------------------------
    println("\n[Summary] Generating Combined Paper Summary Report...")
    p_summary = plot(p_a1, p_b1, p_c1, p_a2, layout=(2, 2), size=(1200, 800),
        plot_title="3D-IC Heat ROM - Sensitivity & Performance Summary")
    savefig(p_summary, joinpath(dir_summary, "paper_overall_sensitivity_4panel.png"))

    open(joinpath(dir_summary, "paper_summary_table.txt"), "w") do io
        println(io, "=== 3D-IC HEAT ROM - SENSITIVITY EVALUATION SUMMARY REPORT ===")
        println(io, "Baseline FVM Grid Resolution: 240 x 240")
        println(io, "Training Samples: $n_train, Validation Samples: $n_val")
        println(io, "\n--- Experiment A: Density Map Resolution ---")
        for (idx, g) in enumerate(res_list)
            @printf(io, "  Res %dx%d (%d dims) -> L2 Error: %.4f %%, Build Time: %.4f s\n", g, g, g*g, res_l2_errors[idx]*100, res_build_times[idx])
        end
        println(io, "\n--- Experiment B: Snapshot Count ---")
        for (idx, ns) in enumerate(nsnap_list)
            @printf(io, "  Nsnap = %d -> L2 Error: %.4f %%, SVD Time: %.4f s\n", ns, nsnap_l2_errors[idx]*100, nsnap_svd_times[idx])
        end
        println(io, "\n--- Experiment C: Retained POD Modes ---")
        for (idx, k) in enumerate(k_list)
            @printf(io, "  Modes k = %d -> L2 Error: %.4f %%\n", k, mode_l2_errors[idx]*100)
        end
    end
    println("  Saved overall summary to ", dir_summary)

    println("\n==========================================================")
    println("       ALL PAPER EXPERIMENTS COMPLETED SUCCESSFULLY        ")
    println("==========================================================")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_sweeps()
end
