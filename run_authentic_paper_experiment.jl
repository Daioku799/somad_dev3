#!/usr/bin/env julia

# run_authentic_paper_experiment.jl
# 240x240物理計算格子における「本物の3D-FVMソルバー (PBiCGSTAB)」を用いた
# 密度マップ解像度 (2x2, 4x4, 8x8, 16x16) の完全比較実験・全自動一括実行スクリプト (既存計算キャッシュ再利用対応)

using JLD2
using JSON
using Printf
using LinearAlgebra
using Plots
using Statistics
using Dates

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

if !isdefined(Main, :ROMValidator)
    include(abspath("H2-rom/src/ROMValidator/ROMValidator.jl"))
end
using .ROMValidator

if !isdefined(Main, :ValidationPlot)
    include(abspath("H2-rom/src/ValidationPlot/ValidationPlot.jl"))
end
using .ValidationPlot

if !isdefined(Main, :PaperEvaluation)
    include(abspath("H2-rom/src/PaperEvaluation/PaperEvaluation.jl"))
end
using .PaperEvaluation

if !isdefined(Main, :SnapshotGenerator)
    include(abspath("H2-rom/src/SnapshotGenerator/SnapshotGenerator.jl"))
end
using .SnapshotGenerator

"""
解像度が異なっても物理的に統一・同等なテストパターン mu_test を生成する関数
中央が高密度、周辺が低密度の標準化密度マップ
"""
function generate_unified_test_mu(g::Int)
    mu = zeros(Float64, g, g)
    cx, cy = (g + 1) / 2.0, (g + 1) / 2.0
    max_r = sqrt(2 * (g/2)^2)
    for j in 1:g, i in 1:g
        r = sqrt((i - cx)^2 + (j - cy)^2)
        mu[j, i] = clamp(0.8 - 0.6 * (r / max_r), 0.1, 0.9)
    end
    return vec(mu)
end

function run_authentic_experiment()
    println("==========================================================")
    println("  AUTHENTIC 3D-FVM HEAT ROM PAPER EXPERIMENT (240x240 Grid)")
    println("  Solver: Real PBiCGSTAB 3D-FVM Heat Equation Solver       ")
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
    nxy_fvm = 240 # 240x240 物理計算格子

    solver_dir = abspath("H2-main-ext")
    work_base = abspath("data/work_sweeps")
    mkpath(work_base)

    res_l2_errors = Float64[]
    res_tmax_errors = Float64[]
    res_fvm_times = Float64[]
    res_rom_times = Float64[]

    for g in res_list
        mu_dim = g * g
        println("\n----------------------------------------------------------")
        println(" [Experiment A] Real 3D-FVM Execution: $(g)x$(g) Density Map ($(mu_dim) dims)")
        println("----------------------------------------------------------")

        samples = SnapshotGenerator.Sampler.generate_samples(n_samples_per_res - 1, (g, g); n_limit=min(16, mu_dim))
        mu_test_unified = generate_unified_test_mu(g)
        push!(samples, mu_test_unified)

        n_tr = round(Int, n_samples_per_res * 0.75)
        tr_samples = samples[1:n_tr]
        val_samples = samples[(n_tr+1):end]

        base_config = SnapshotGenerator.Runner.default_model_config()

        temp_tr, mu_tr = Vector{Float64}[], Vector{Float64}[]
        temp_val, mu_val = Vector{Float64}[], Vector{Float64}[]
        
        t_fvm_start = time()

        # 訓練サンプル
        for (i, mu_vec) in enumerate(tr_samples)
            case_id = g * 1000 + i
            c = SnapshotGenerator.Types.SnapshotCase(case_id, "pending", mu_vec, "", 0.0)
            density_cfg = SnapshotGenerator.Sampler.H2MainExt.ConfigLoader.Types.DensityMapConfig(
                g, g, mu_vec, 0, min(16, mu_dim), 1.0, Tuple{Int,Int}[]
            )
            tsv_cfg = SnapshotGenerator.Sampler.H2MainExt.ConfigLoader.Types.TSVConfig(
                :density, base_config.tsv.coords, base_config.tsv.radius, base_config.tsv.height,
                density_cfg, base_config.tsv.manufacturing, base_config.tsv.ga
            )
            config = SnapshotGenerator.Sampler.H2MainExt.ConfigLoader.Types.ModelConfig(
                base_config.materials, base_config.layers, tsv_cfg,
                base_config.lx, base_config.ly, base_config.pg_dpth, base_config.s_dpth,
                base_config.d_ufill, base_config.r_bump, true, work_base,
                base_config.fixed_silicon_lambda, base_config.epsilon, base_config.max_iter
            )

            case_dir = joinpath(work_base, "case_$(case_id)")
            snapshot_file = joinpath(case_dir, "snapshot.jld2")

            if !isfile(snapshot_file)
                print("  -> FVM Train Solve ($(i)/$(n_tr)) for $(g)x$(g)... ")
                case_dir = SnapshotGenerator.Runner.prepare_work_dir(c, work_base)
                SnapshotGenerator.Runner.generate_case_configs(c, config, case_dir)
                abs_run_jl = abspath(joinpath(solver_dir, "run.jl"))
                cmd = `julia --project=$(solver_dir) $(abs_run_jl) $(nxy_fvm) $(nxy_fvm) 13 pbicgstab gs 1e-4 sequential true --snapshot $(snapshot_file)`
                log_file = joinpath(case_dir, "output.log")
                open(log_file, "w") do out
                    run(pipeline(setenv(cmd, dir=case_dir), stdout=out, stderr=out))
                end
                println("Done.")
            else
                println("  -> FVM Train Solve ($(i)/$(n_tr)) for $(g)x$(g)... (Cached)")
            end

            jld = jldopen(snapshot_file, "r")
            t_field = haskey(jld, "temperature") ? jld["temperature"] : (haskey(jld, "theta") ? jld["theta"] : jld["θ"])
            push!(temp_tr, vec(t_field))
            push!(mu_tr, mu_vec)
            close(jld)
        end

        # 検証サンプル
        for (i, mu_vec) in enumerate(val_samples)
            case_id = g * 1000 + n_tr + i
            c = SnapshotGenerator.Types.SnapshotCase(case_id, "pending", mu_vec, "", 0.0)
            density_cfg = SnapshotGenerator.Sampler.H2MainExt.ConfigLoader.Types.DensityMapConfig(
                g, g, mu_vec, 0, min(16, mu_dim), 1.0, Tuple{Int,Int}[]
            )
            tsv_cfg = SnapshotGenerator.Sampler.H2MainExt.ConfigLoader.Types.TSVConfig(
                :density, base_config.tsv.coords, base_config.tsv.radius, base_config.tsv.height,
                density_cfg, base_config.tsv.manufacturing, base_config.tsv.ga
            )
            config = SnapshotGenerator.Sampler.H2MainExt.ConfigLoader.Types.ModelConfig(
                base_config.materials, base_config.layers, tsv_cfg,
                base_config.lx, base_config.ly, base_config.pg_dpth, base_config.s_dpth,
                base_config.d_ufill, base_config.r_bump, true, work_base,
                base_config.fixed_silicon_lambda, base_config.epsilon, base_config.max_iter
            )

            case_dir = joinpath(work_base, "case_$(case_id)")
            snapshot_file = joinpath(case_dir, "snapshot.jld2")

            if !isfile(snapshot_file)
                print("  -> FVM Val Solve ($(i)/$(length(val_samples))) for $(g)x$(g)... ")
                case_dir = SnapshotGenerator.Runner.prepare_work_dir(c, work_base)
                SnapshotGenerator.Runner.generate_case_configs(c, config, case_dir)
                abs_run_jl = abspath(joinpath(solver_dir, "run.jl"))
                cmd = `julia --project=$(solver_dir) $(abs_run_jl) $(nxy_fvm) $(nxy_fvm) 13 pbicgstab gs 1e-4 sequential true --snapshot $(snapshot_file)`
                log_file = joinpath(case_dir, "output.log")
                open(log_file, "w") do out
                    run(pipeline(setenv(cmd, dir=case_dir), stdout=out, stderr=out))
                end
                println("Done.")
            else
                println("  -> FVM Val Solve ($(i)/$(length(val_samples))) for $(g)x$(g)... (Cached)")
            end

            jld = jldopen(snapshot_file, "r")
            t_field = haskey(jld, "temperature") ? jld["temperature"] : (haskey(jld, "theta") ? jld["theta"] : jld["θ"])
            push!(temp_val, vec(t_field))
            push!(mu_val, mu_vec)
            close(jld)
        end

        t_fvm_total = time() - t_fvm_start

        X_tr = reduce(hcat, temp_tr)
        Mu_tr = reduce(hcat, mu_tr)
        X_v = reduce(hcat, temp_val)
        Mu_v = reduce(hcat, mu_val)

        # 2. POD + RBF ROM 構築
        t_rom_start = time()
        basis, _, coeffs_tr, mean_f = PODEngine.compute_pod(X_tr; ric_threshold=0.999)
        rbf = ROMInterpolator.RBFInterpolator(1.0)
        ROMInterpolator.fit!(rbf, Mu_tr, coeffs_tr; lambda=1e-6)
        t_rom_build = time() - t_rom_start

        # 3. 性能検証
        l2_errs = Float64[]
        tmax_errs = Float64[]

        for i in 1:size(X_v, 2)
            c_pred = ROMInterpolator.predict(rbf, Mu_v[:, i])
            theta_pred = ROMInterpolator.reconstruct_field(c_pred, basis, mean_f)
            theta_fvm = X_v[:, i]

            l2_err = norm(theta_fvm .- theta_pred) / norm(theta_fvm)
            tmax_err = abs(maximum(theta_fvm) - maximum(theta_pred))

            push!(l2_errs, l2_err)
            push!(tmax_errs, tmax_err)
        end

        mean_l2 = mean(l2_errs)
        mean_tmax = mean(tmax_errs)

        push!(res_l2_errors, mean_l2)
        push!(res_tmax_errors, mean_tmax)
        push!(res_fvm_times, t_fvm_total)
        push!(res_rom_times, t_rom_build)

        # 4. 既存プロットプログラム (ValidationPlot) を呼び出して個別図面・比較図を出力
        val_case_dir = joinpath(work_base, "case_$(g * 1000 + n_tr + length(val_samples))")
        unified_snapshot_file = joinpath(val_case_dir, "snapshot.jld2")

        if isfile(unified_snapshot_file)
            try
                ValidationPlot.plot_snapshot_xy(
                    unified_snapshot_file;
                    zc=0.33e-3,
                    out_dir=joinpath(dir_01_res, "res_$(g)x$(g)"),
                    save_individuals=true
                )
            catch e
                println("  -> Plotting warning for $(g)x$(g): $e")
            end
        end

        @printf("  [Result %dx%d] Mean L2: %.4f %%, Tmax Err: %.2f K, FVM Time: %.2f s, ROM Time: %.4f s\n",
                g, g, mean_l2 * 100, mean_tmax, t_fvm_total, t_rom_build)
    end

    # 5. 横並び比較プロット生成
    println("\nGenerating Multi-Resolution Comparative Plots under plots/for_paper/...")
    p_a1, p_a2 = PaperEvaluation.plot_density_resolution_sweep(res_list, res_l2_errors, res_rom_times, dir_01_res)

    open(joinpath(dir_01_res, "authentic_fvm_density_resolution_summary.txt"), "w") do io
        println(io, "Gx\tDim\tL2_Error[%]\tTmax_Error[K]\tFVM_Total_Time[s]\tROM_Build_Time[s]")
        for (idx, g) in enumerate(res_list)
            @printf(io, "%d\t%d\t%.4f\t%.2f\t%.2f\t%.4f\n",
                    g, g*g, res_l2_errors[idx]*100, res_tmax_errors[idx], res_fvm_times[idx], res_rom_times[idx])
        end
    end

    p_summary = plot(p_a1, p_a2, layout=(1, 2), size=(1000, 420),
                     plot_title="Authentic 3D-FVM Sensitivity & Performance (240x240 Grid)")
    savefig(p_summary, joinpath(dir_summary, "paper_overall_sensitivity_4panel.png"))

    open(joinpath(dir_summary, "paper_summary_table.txt"), "w") do io
        println(io, "=== 3D-IC HEAT ROM - AUTHENTIC 3D-FVM SENSITIVITY REPORT ===")
        println(io, "Unified Baseline FVM Grid: 240 x 240")
        println(io, "Solver: Real PBiCGSTAB 3D-FVM Heat Equation Solver")
        println(io, "\n--- Experiment A: Density Map Resolution Sweeps ---")
        for (idx, g) in enumerate(res_list)
            @printf(io, "  Res %dx%d (%d dims) -> Mean L2 Error: %.4f %%, Tmax Err: %.2f K, FVM Time: %.2f s, ROM Build Time: %.4f s\n",
                    g, g, g*g, res_l2_errors[idx]*100, res_tmax_errors[idx], res_fvm_times[idx], res_rom_times[idx])
        end
    end

    println("\n==========================================================")
    println("   AUTHENTIC 3D-FVM EXPERIMENTS COMPLETED SUCCESSFULLY    ")
    println("==========================================================")
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_authentic_experiment()
end
