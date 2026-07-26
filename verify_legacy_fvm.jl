#!/usr/bin/env julia

# verify_legacy_fvm.jl
# 新旧FVM等価性検証メインスクリプト

using JLD2
using Printf
using LinearAlgebra
using Plots

if !isdefined(Main, :ValidationPlot)
    include(joinpath(@__DIR__, "H2-rom", "src", "ValidationPlot", "ValidationPlot.jl"))
end
using .ValidationPlot

# 現行モジュールをロードするためのロードパス追加
push!(LOAD_PATH, joinpath(@__DIR__, "H2-main-ext", "src"))

# heat3ds.jlをインクルード
include(joinpath(@__DIR__, "H2-main-ext", "src", "heat3ds.jl"))

using .modelA
using .modelA.ModelBuilder
using .modelA.ModelBuilder.ConfigLoader

function main_verification()
    println("=== New/Legacy FVM Equivalence Verification ===")
    
    # 1. 現行モデルの構築
    NX, NY, NZ = 60, 60, 30
    default_config = joinpath(@__DIR__, "H2-main-ext", "config.json")
    fallback_config = joinpath(@__DIR__, "legacy", "H2-main_TSV_Opt", "config.json")
    config_path = isfile(default_config) ? default_config : fallback_config

    default_tsv = joinpath(@__DIR__, "H2-main-ext", "tsv_config.json")
    fallback_tsv = joinpath(@__DIR__, "legacy", "H2-main_TSV_Opt", "tsv_config.json")
    tsv_config_path = isfile(default_tsv) ? default_tsv : fallback_tsv
    
    println("Loading configuration from:")
    println("  config: ", config_path)
    println("  tsv_config: ", tsv_config_path)
    
    config = ModelBuilder.ConfigLoader.load_config(config_path, tsv_config_path)
    ID, λ, ρ, cp, coordsys = ModelBuilder.build_model(config, NX)
    
    SZ = size(ID)
    MX, MY, MZ = SZ
    println("Model built successfully. Grid size: ", SZ)
    
    # 2. 現行のFVMソルバー実行
    println("Running current FVM solver (sequential, epsilon=1e-6)...")
    
    # WorkBuffersの作成と物性のコピー
    wk = WorkBuffers(MX, MY, MZ)
    wk.λ .= λ
    wk.ρ .= ρ
    wk.cp .= cp
    
    # 境界条件設定と適用
    bc_set = set_mode3_bc_parameters()
    θ_init = 300.0
    wk.θ .= θ_init 
    BoundaryConditions.apply_boundary_conditions!(wk.θ, wk.λ, wk.ρ, wk.cp, wk.mask, bc_set)
    
    # パラメータ設定
    solver = "pbicgstab"
    smoother = "gs"
    epsilon = 1.0e-6
    par = "sequential"
    is_steady = true
    
    # 許容残差のグローバル変数を設定
    global itr_tol = epsilon
    
    dx = config.lx / NX
    dy = config.ly / NY
    Δh = (dx, dy, 1.0)
    Δt = 10000.0
    ZC = coordsys.z_centers
    ΔZ = coordsys.dz_grid
    
    # ソルバーの実行
    main(Δh, Δt, wk, ZC, ΔZ, ID, solver, smoother, bc_set, par, is_steady=is_steady)
    theta_new = copy(wk.θ)
    println("Current FVM solver finished.")
    
    # 3. 一時JLD2ファイルへのIDマップ等書き出し
    temp_dir = joinpath(@__DIR__, "data", "work")
    mkpath(temp_dir)
    id_map_path = joinpath(temp_dir, "temp_id_map.jld2")
    
    println("Writing temporary id_map to: ", id_map_path)
    # レガシーに新ソルバーで生成された MZ=32 のモデルを直接渡す
    jldsave(id_map_path; ID=ID, lambda=λ, rho=ρ, cp=cp, Z=coordsys.Z, ZC=coordsys.z_centers, dZ=coordsys.dz_grid)
    
    # 4. legacy_run_wrapper.jl を外部プロセスで実行
    wrapper_script = joinpath(@__DIR__, "legacy", "H2-main-original", "legacy_run_wrapper.jl")
    project_path = joinpath(@__DIR__, "H2-main-ext")
    
    println("Spawning legacy FVM solver wrapper...")
    cmd = `julia --project=$project_path $wrapper_script --id-map $id_map_path`
    
    try
        if !success(cmd)
            error("Subprocess execution failed.")
        end
    catch e
        println("ERROR during subprocess launch: ", e)
        rethrow(e)
    end
    
    # 5. レガシー結果の読み込み
    legacy_output_path = joinpath(temp_dir, "temp_legacy_temp.jld2")
    if !isfile(legacy_output_path)
        error("Expected output file from legacy solver not found: $legacy_output_path")
    end
    
    println("Loading legacy FVM solver results from: ", legacy_output_path)
    theta_legacy = jldopen(legacy_output_path, "r") do file
        file["theta_legacy"]
    end
    
    # 6. アサーション検証 (物理内部セル k = 2:31 で比較)
    theta_new_internal = theta_new[:, :, 2:31]
    theta_legacy_internal = theta_legacy[:, :, 2:31]
    
    diff = abs.(theta_new_internal .- theta_legacy_internal)
    max_diff = maximum(diff)
    
    println("Verification summary:")
    println("  Max absolute difference (internal cells): ", max_diff, " K")
    
    if max_diff > 1e-12
        # エラー座標の特定
        idx = argmax(diff)
        i, j, k_offset = idx.I
        k = k_offset + 1
        println("ERROR: Temperature equivalence check FAILED.")
        println("  Max absolute difference: ", max_diff, " K")
        println("  Coordinates of max error: (i=$i, j=$j, k=$k)")
        println("  New FVM temperature: ", theta_new_internal[idx], " K")
        println("  Legacy FVM temperature: ", theta_legacy_internal[idx], " K")
        
        @assert max_diff <= 1e-12 "Maximum temperature difference ($max_diff) exceeds threshold (1e-12)."
    else
        println("SUCCESS: Temperature equivalence check PASSED.")
        
        # 7. プロットの出力 (4.2要件)
        println("Generating verification plots...")
        plots_out_dir = joinpath(@__DIR__, "plots", "legacy_verification")
        mkpath(plots_out_dir)
        
        # 原点定義
        ox = (0.0, 0.0, 0.0)
        
        # 代表的な座標定義 (Silicon1/Underfill2境界付近)
        zc = 0.33e-3
        yc = 0.6e-3
        
        # 7.1 材質プロット
        ValidationPlot.plot_heatsource_tsv_overlay_nu_save(ID, zc, SZ, ox, Δh, coordsys.Z, joinpath(plots_out_dir, "material_xy.png"))
        
        # 7.2 新旧温度比較(XY断面)
        p_temp_new_xy = ValidationPlot.plot_slice_xy_nu_return(3, 2, theta_new, zc, SZ, ox, Δh, coordsys.Z, "New FVM")
        p_temp_legacy_xy = ValidationPlot.plot_slice_xy_nu_return(3, 2, theta_legacy, zc, SZ, ox, Δh, coordsys.Z, "Legacy FVM")
        p_comp_xy = plot(p_temp_new_xy, p_temp_legacy_xy, layout=(1, 2), size=(1800, 500))
        savefig(p_comp_xy, joinpath(plots_out_dir, "temperature_comparison_xy.png"))
        
        # 7.3 新旧温度比較(XZ断面)
        function make_xz_plot(d, y_val, title_str)
            xs = 2
            xe = SZ[1] - 1
            zs = 2
            ze = SZ[3] - 1
            j = ValidationPlot.find_j(y_val, ox[2], Δh[2], SZ[2])
            s = d[xs:xe, j, zs:ze]
            
            x_coords = [(ox[1] + Δh[1] * (i - 1.5)) * 1000.0 for i in xs:xe]
            z_coords = [coordsys.Z[k] * 1000.0 for k in zs:ze]
            
            p = contour(z_coords, x_coords, s, 
                        fill=true, c=:thermal,
                        xlims=(0.0, 0.6), ylims=(0.0, 1.2),
                        xlabel="Z [mm]", ylabel="X [mm]",
                        title=title_str, aspect_ratio=:equal)
            return p
        end
        
        p_temp_new_xz = make_xz_plot(theta_new, yc, "New FVM (XZ)")
        p_temp_legacy_xz = make_xz_plot(theta_legacy, yc, "Legacy FVM (XZ)")
        p_comp_xz = plot(p_temp_new_xz, p_temp_legacy_xz, layout=(1, 2), size=(1800, 500))
        savefig(p_comp_xz, joinpath(plots_out_dir, "temperature_comparison_xz.png"))
        
        # 7.4 温度差分ヒートマップ
        k_idx = ValidationPlot.find_k(coordsys.Z, zc, SZ[3], 3)
        s_diff = abs.(theta_new[2:SZ[1]-1, 2:SZ[2]-1, k_idx] .- theta_legacy[2:SZ[1]-1, 2:SZ[2]-1, k_idx])
        
        x_coords = [(ox[1] + Δh[1] * (i - 1.5)) * 1000.0 for i in 2:SZ[1]-1]
        y_coords = [(ox[2] + Δh[2] * (j - 1.5)) * 1000.0 for j in 2:SZ[2]-1]
        
        p_diff = heatmap(x_coords, y_coords, s_diff',
                         fill=true, c=:viridis, aspect_ratio=:equal,
                         title="Absolute Temperature Difference (New - Legacy)\nMax Diff = $(maximum(s_diff)) K",
                         xlabel="X [mm]", ylabel="Y [mm]")
        savefig(p_diff, joinpath(plots_out_dir, "temperature_diff_heatmap.png"))
        
        println("All verification plots saved to: ", plots_out_dir)

        # 一時ファイルの削除
        try
            rm(id_map_path, force=true)
            rm(legacy_output_path, force=true)
            println("Temporary files cleaned up.")
        catch e
            @warn "Failed to remove temporary files: " e
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_verification()
end
