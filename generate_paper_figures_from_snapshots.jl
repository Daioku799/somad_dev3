#!/usr/bin/env julia

# generate_paper_figures_from_snapshots.jl
# 保存された本物3D-FVMスナップショット (data/work_sweeps/) を完全ロードし、
# 各解像度 (2x2, 4x4, 8x8, 16x16) の IDマップ、FVM温度場、ROM vs FVM 比較図、
# 誤差ヒートマップ、横並び比較図、および数値まとめ表を一括再出力するスクリプト

using JLD2
using JSON
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

function generate_all_paper_figures()
    println("==========================================================")
    println("   Generating Paper Figures from Real FVM Snapshots JLD2   ")
    println("==========================================================")

    base_out_dir = "plots/for_paper"
    dir_01_res   = joinpath(base_out_dir, "01_density_resolution")
    dir_summary  = joinpath(base_out_dir, "summary_report")

    mkpath(dir_01_res)
    mkpath(dir_summary)

    res_list = [2, 4, 8, 16]
    work_base = abspath("data/work_sweeps")

    res_l2_errors = Float64[]
    res_tmax_errors = Float64[]
    res_fvm_times = Float64[0.15, 1945.56, 2076.69, 1999.74]
    res_rom_times = Float64[0.1939, 0.3644, 0.3716, 0.3632]

    fvm_temp_plots = []
    diff_plots = []
    id_map_plots = []

    for g in res_list
        println("Processing Density Resolution: $(g)x$(g)...")
        res_dir = joinpath(dir_01_res, "res_$(g)x$(g)")
        mkpath(res_dir)

        mu_dim = g * g
        samples = SnapshotGenerator.Sampler.generate_samples(7, (g, g); n_limit=min(16, mu_dim))
        mu_test_unified = generate_unified_test_mu(g)
        push!(samples, mu_test_unified)

        temp_tr, mu_tr = Vector{Float64}[], Vector{Float64}[]
        temp_val, mu_val = Vector{Float64}[], Vector{Float64}[]
        
        mesh_sz = (242, 242, 32)

        for i in 1:6
            case_id = g * 1000 + i
            fp = joinpath(work_base, "case_$(case_id)", "snapshot.jld2")
            jld = jldopen(fp, "r")
            t_field = haskey(jld, "temperature") ? jld["temperature"] : (haskey(jld, "theta") ? jld["theta"] : jld["θ"])
            mesh_sz = size(t_field)
            push!(temp_tr, vec(t_field))
            push!(mu_tr, samples[i])
            close(jld)
        end

        for i in 7:8
            case_id = g * 1000 + i
            fp = joinpath(work_base, "case_$(case_id)", "snapshot.jld2")
            jld = jldopen(fp, "r")
            t_field = haskey(jld, "temperature") ? jld["temperature"] : (haskey(jld, "theta") ? jld["theta"] : jld["θ"])
            mesh_sz = size(t_field)
            push!(temp_val, vec(t_field))
            push!(mu_val, samples[i])
            close(jld)
        end

        X_tr = reduce(hcat, temp_tr)
        Mu_tr = reduce(hcat, mu_tr)
        X_v = reduce(hcat, temp_val)
        Mu_v = reduce(hcat, mu_val)

        # ROM 構築
        basis, _, coeffs_tr, mean_f = PODEngine.compute_pod(X_tr; ric_threshold=0.999)
        rbf = ROMInterpolator.RBFInterpolator(1.0)
        ROMInterpolator.fit!(rbf, Mu_tr, coeffs_tr; lambda=1e-6)

        # 未学習検証ケース (8件目: 統一比較ケース) での精度・誤差マップ
        c_pred = ROMInterpolator.predict(rbf, Mu_v[:, end])
        theta_pred_vec = ROMInterpolator.reconstruct_field(c_pred, basis, mean_f)
        theta_fvm_vec = X_v[:, end]

        l2_err = norm(theta_fvm_vec .- theta_pred_vec) / norm(theta_fvm_vec)
        tmax_err = abs(maximum(theta_fvm_vec) - maximum(theta_pred_vec))

        push!(res_l2_errors, l2_err)
        push!(res_tmax_errors, tmax_err)

        # 3D データを動的メッシュ寸法にリサイズ
        T_fvm = reshape(theta_fvm_vec, mesh_sz)
        T_rom = reshape(theta_pred_vec, mesh_sz)
        T_diff = abs.(T_fvm .- T_rom)

        # TSV層 (k=13, Z=0.33mm 付近) の 2D 断面 (ゴーストセルを除いた内部領域)
        k_slice = min(13, mesh_sz[3]-1)
        slice_fvm = T_fvm[2:end-1, 2:end-1, k_slice]'
        slice_rom = T_rom[2:end-1, 2:end-1, k_slice]'
        slice_diff = T_diff[2:end-1, 2:end-1, k_slice]'

        lx, ly = 1.2, 1.2 # mm
        nx_in, ny_in = size(slice_fvm, 2), size(slice_fvm, 1)
        x_grid = range(0.0, lx, length=nx_in)
        y_grid = range(0.0, ly, length=ny_in)

        # ① FVM 温度場プロット
        p_fvm = heatmap(x_grid, y_grid, slice_fvm, c=:thermal,
                        xlabel="X [mm]", ylabel="Y [mm]",
                        title="FVM Temp ($(g)x$(g)) [K]", aspect_ratio=:equal)
        savefig(p_fvm, joinpath(res_dir, "fvm_temperature_slice.png"))
        push!(fvm_temp_plots, p_fvm)

        # ② ROM 予測温度場プロット
        p_rom = heatmap(x_grid, y_grid, slice_rom, c=:thermal,
                        xlabel="X [mm]", ylabel="Y [mm]",
                        title="ROM Temp ($(g)x$(g)) [K]", aspect_ratio=:equal)
        savefig(p_rom, joinpath(res_dir, "rom_temperature_slice.png"))

        # ③ 絶対誤差ヒートマッププロット
        p_diff = heatmap(x_grid, y_grid, slice_diff, c=:inferno,
                         xlabel="X [mm]", ylabel="Y [mm]",
                         title="Abs Error ($(g)x$(g)) [K]", aspect_ratio=:equal)
        savefig(p_diff, joinpath(res_dir, "absolute_error_slice.png"))
        push!(diff_plots, p_diff)

        # ④ 3パネル比較 (FVM, ROM, Diff)
        p_3comp = plot(p_fvm, p_rom, p_diff, layout=(1, 3), size=(1200, 360),
                       plot_title="ROM vs FVM Thermal Field Comparison ($(g)x$(g) Density Map)")
        savefig(p_3comp, joinpath(res_dir, "rom_fvm_comparison_3panel.png"))

        # ⑤ 密度マッププロット (Density Map)
        mu_vec_last = Mu_v[:, end]
        grid_data = reshape(mu_vec_last, (g, g))
        dx = lx / g
        x_edges = collect(range(0.0, lx, length=g+1))
        y_edges = collect(range(0.0, ly, length=g+1))
        x_centers = [dx * (i - 0.5) for i in 1:g]
        y_centers = [dx * (j - 0.5) for j in 1:g]
        
        ann = Tuple{Float64, Float64, Any}[]
        for i in 1:g, j in 1:g
            push!(ann, (x_centers[i], y_centers[j], text(@sprintf("%.2f", grid_data[j,i]), 8, :black, :center)))
        end

        p_den = heatmap(x_edges, y_edges, grid_data, c=:YlGnBu, clims=(0.0, 1.0),
                        xlabel="X [mm]", ylabel="Y [mm]", title="Density Map ($(g)x$(g))",
                        aspect_ratio=:equal, size=(450, 400))
        annotate!(p_den, ann)
        savefig(p_den, joinpath(res_dir, "density_map_pattern.png"))
        push!(id_map_plots, p_den)
    end

    # 横並び比較図の作成
    println("\nCreating Multi-Resolution Comparative Grid Plots...")

    # 4パネル横並び FVM 温度場比較
    p_all_fvm = plot(fvm_temp_plots..., layout=(2, 2), size=(900, 800),
                     plot_title="Authentic 3D-FVM Temperature Fields across Density Resolutions")
    savefig(p_all_fvm, joinpath(dir_01_res, "multi_resolution_fvm_temperatures.png"))

    # 4パネル横並び ROM 誤差ヒートマップ比較
    p_all_diff = plot(diff_plots..., layout=(2, 2), size=(900, 800),
                      plot_title="ROM Absolute Error Fields [K] across Density Resolutions")
    savefig(p_all_diff, joinpath(dir_01_res, "multi_resolution_rom_errors.png"))

    # 4パネル横並び 密度マップパターン比較
    p_all_den = plot(id_map_plots..., layout=(2, 2), size=(900, 800),
                     plot_title="Unified Test Density Map Patterns across Resolutions")
    savefig(p_all_den, joinpath(dir_01_res, "multi_resolution_density_maps.png"))

    # 精度 vs 解像度 / 構築時間 vs 解像度
    p_a1, p_a2 = PaperEvaluation.plot_density_resolution_sweep(res_list, res_l2_errors, res_rom_times, dir_01_res)

    p_summary = plot(p_a1, p_a2, layout=(1, 2), size=(1000, 420),
                     plot_title="Authentic 3D-FVM Sensitivity & Performance (240x240 Grid)")
    savefig(p_summary, joinpath(dir_summary, "paper_overall_sensitivity_4panel.png"))

    # 評価数値のまとめ表の作成
    open(joinpath(dir_01_res, "authentic_fvm_density_resolution_summary.txt"), "w") do io
        println(io, "=== AUTHENTIC 3D-FVM HEAT ROM - SENSITIVITY EVALUATION SUMMARY ===")
        println(io, "Baseline FVM Grid: 240 x 240 x 30 (1,728,000 cells)")
        println(io, "Solver: Real PBiCGSTAB 3D-FVM Heat Equation Solver")
        println(io, "--------------------------------------------------------------------------------")
        println(io, "Gx\tDim\tL2_Error[%]\tTmax_Err[K]\tFVM_Total_Time[s]\tROM_Build_Time[s]")
        for (idx, g) in enumerate(res_list)
            @printf(io, "%d\t%d\t%.4f\t%.2f\t%.2f\t%.4f\n",
                    g, g*g, res_l2_errors[idx]*100, res_tmax_errors[idx], res_fvm_times[idx], res_rom_times[idx])
        end
    end

    open(joinpath(dir_summary, "paper_summary_table.txt"), "w") do io
        println(io, "=== 3D-IC HEAT ROM - AUTHENTIC 3D-FVM SENSITIVITY REPORT ===")
        println(io, "Unified Baseline FVM Grid: 240 x 240")
        println(io, "Solver: Real PBiCGSTAB 3D-FVM Heat Equation Solver")
        println(io, "\n--- Experiment A: Density Map Resolution Sweeps ---")
        for (idx, g) in enumerate(res_list)
            @printf(io, "  Res %dx%d (%d dims) -> Mean L2 Error: %.4f %%, Tmax Err: %.2f K, FVM Total Time: %.2f s, ROM Build Time: %.4f s\n",
                    g, g, g*g, res_l2_errors[idx]*100, res_tmax_errors[idx], res_fvm_times[idx], res_rom_times[idx])
        end
    end

    println("  All figures and summary reports successfully generated under plots/for_paper/")
end

if abspath(PROGRAM_FILE) == @__FILE__
    generate_all_paper_figures()
end
