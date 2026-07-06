using Test
using Printf
using JLD2

# 1. 依存モジュールのロード
println(">>> 1. Loading core modules...")
include(joinpath(abspath("H2-main-ext/src"), "modelA.jl"))
using .modelA
if !isdefined(Main, :q3d)
    include(joinpath(abspath("H2-main-ext/src"), "heat3ds.jl"))
end
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

# 出力ディレクトリの設定
out_dir = "rom_plots"
mkpath(out_dir)

# 格子サイズ設定 (FVM)
NX, NY, NZ = 60, 60, 30

println("\n==================================================")
println("     ROM Interactive Verification Playground")
println("==================================================")

try
    # ----------------------------------------------------------------
    # TEST 1: スナップショットの自動生成と可視化
    # ----------------------------------------------------------------
    println("\n[TEST 1] Generating Snapshots (FVM)...")
    
    # 3パターンの設計パラメータ μ (4x4 = 16セル密度分布) を定義
    # パターン1: 一様分布
    mu1 = fill(0.5, 16)
    # パターン2: 中央集中
    mu2 = [
        0.1, 0.1, 0.1, 0.1,
        0.1, 0.9, 0.9, 0.1,
        0.1, 0.9, 0.9, 0.1,
        0.1, 0.1, 0.1, 0.1
    ]
    # パターン3: 四隅集中
    mu3 = [
        0.9, 0.1, 0.1, 0.9,
        0.1, 0.1, 0.1, 0.1,
        0.1, 0.1, 0.1, 0.1,
        0.9, 0.1, 0.1, 0.9
    ]
    
    mu_list = [mu1, mu2, mu3]
    snapshot_files = String[]
    
    for (idx, mu) in enumerate(mu_list)
        snap_path = joinpath(out_dir, "snapshot_$(idx).jld2")
        push!(snapshot_files, snap_path)
        
        # 密度マップパラメータ自体のプロット保存
        ValidationPlot.plot_density_map(mu, joinpath(out_dir, "density_map_$(idx).png"), title="TSV Density Map $(idx)")
        println("  -> Visualized density map $(idx) to: $(out_dir)/density_map_$(idx).png")
        
        println("  -> Running FVM for mu_$(idx)...")
        
        # tsv_config.json の動的生成
        tsv_json = """
        {
          "tsv_mode": "density",
          "tsv_radius": 2.0e-5,
          "density_map": {
            "gx": 4, "gy": 4,
            "mu": $(mu),
            "n_min": 0, "n_max": 120,
            "rho_cell_max": 1.0,
            "prohibited_cells": []
          },
          "manufacturing": {
            "d_tsv": 4.0e-5, "p_min": 8.0e-5,
            "aspect_ratio_min": 2.5, "aspect_ratio_max": 10.0
          }
        }
        """
        write("tsv_config.json", tsv_json)
        
        # 物理構造用の config.json (退避されたレガシーファイルからコピー)
        cp("legacy/H2-main_TSV_Opt/config.json", "config.json", force=true)
        
        # FVM実行と保存
        q3d(NX, NY, NZ, "cg", "gs"; epsilon=1e-5, par="sequential", is_steady=true, snapshot_path=snap_path, mu=mu)
        
        # 正常に生成されているかアサート
        @assert isfile(snap_path) "Snapshot file not generated!"
        
        # スナップショットの可視化 (温度スケール 330K - 350K に固定)
        ValidationPlot.plot_snapshot_xy(snap_path; zc=0.348e-3, out_dir=out_dir, clims=(330.0, 350.0))
        println("  -> Visualized snapshot $(idx) to: $(out_dir)/snapshot_$(idx)_sidebyside_xy.png")
    end
    
    # ----------------------------------------------------------------
    # TEST 2: POD 基底抽出と特異値の可視化
    # ----------------------------------------------------------------
    println("\n[TEST 2] Performing POD Decomposition & Visualization...")
    temp_fields = Vector{Float64}[]
    for file in snapshot_files
        data = JLD2.load(file)
        push!(temp_fields, vec(data["theta"]))
    end
    X_snap = reduce(hcat, temp_fields)
    
    basis, singular_values, coeffs, mean_field = PODEngine.compute_pod(X_snap; ric_threshold=0.99)
    println("  -> Calculated POD modes: ", size(basis, 2))
    
    # 特異値減衰プロットの生成
    ValidationPlot.plot_singular_values(singular_values; out_dir=out_dir)
    println("  -> Visualized SVD decay to: $(out_dir)/svd_decay_ric.png")
    
    # ----------------------------------------------------------------
    # TEST 3: ROM の学習・保存および復元確認
    # ----------------------------------------------------------------
    println("\n[TEST 3] Training and Persisting ROM Model...")
    Mu = reduce(hcat, mu_list)
    rom_file = joinpath(out_dir, "trained_rom_model.jld2")
    
    rom_model = ROMInterpolator.train_rom(Mu, coeffs, rom_file; epsilon=1.0, lambda=1e-6)
    println("  -> ROM Model saved to: ", rom_file)
    
    # ロードと同一性確認
    loaded_rom = ROMInterpolator.load_rom_model(rom_file)
    println("  -> ROM Model loaded successfully from file.")
    
    # ----------------------------------------------------------------
    # TEST 4: 未知のパラメータに対するROMの予測（低次元近似）と精度可視化
    # ----------------------------------------------------------------
    println("\n[TEST 4] Evaluating ROM Prediction on Unknown Parameter...")
    # 未知のテストパラメータ (学習データに含まれない、全体グラデーション)
    mu_test = [
        0.2, 0.3, 0.4, 0.5,
        0.3, 0.4, 0.5, 0.6,
        0.4, 0.5, 0.6, 0.7,
        0.5, 0.6, 0.7, 0.8
    ]
    
    # 未知パラメータに対する FVM の厳密解を生成
    ref_snap = joinpath(out_dir, "reference_fvm_test.jld2")
    tsv_json_test = """
    {
      "tsv_mode": "density",
      "tsv_radius": 2.0e-5,
      "density_map": {
        "gx": 4, "gy": 4,
        "mu": $(mu_test),
        "n_min": 0, "n_max": 120,
        "rho_cell_max": 1.0,
        "prohibited_cells": []
      },
      "manufacturing": {
        "d_tsv": 4.0e-5, "p_min": 8.0e-5,
        "aspect_ratio_min": 2.5, "aspect_ratio_max": 10.0
      }
    }
    """
    write("tsv_config.json", tsv_json_test)
    
    # テスト用密度マップパラメータ自体のプロット保存
    ValidationPlot.plot_density_map(mu_test, joinpath(out_dir, "density_map_test.png"), title="Unknown TSV Density Map (Test)")
    println("  -> Visualized density map test to: $(out_dir)/density_map_test.png")
    
    q3d(NX, NY, NZ, "cg", "gs"; epsilon=1e-5, par="sequential", is_steady=true, snapshot_path=ref_snap, mu=mu_test)
    
    ref_data = JLD2.load(ref_snap)
    theta_fvm = vec(ref_data["theta"])
    
    # ROM による瞬時予測
    theta_rom = ROMInterpolator.evaluate_rom(loaded_rom, basis, mean_field, mu_test)
    
    # 精度検証 (L2誤差, 最大温度誤差)
    l2_err = ROMValidator.calculate_l2_error(theta_fvm, theta_rom)
    tmax_err = ROMValidator.calculate_tmax_error(theta_fvm, theta_rom)
    
    @printf("  -> Relative L2 Error   : %.6e\n", l2_err)
    @printf("  -> Tmax Absolute Error : %.6f [K]\n", tmax_err)
    
    # 比較プロットの生成 (絶対誤差マップ含む)
    Z_faces = ref_data["z_faces"]
    ValidationPlot.plot_rom_comparison(theta_fvm, theta_rom, (NX+2, NY+2, length(Z_faces)), Z_faces; zc=0.348e-3, out_dir=out_dir, clims=(330.0, 350.0))
    println("  -> Visualized comparison plot to: $(out_dir)/rom_fvm_comparison_xy.png")
    
    # ----------------------------------------------------------------
    # TEST 5: 外挿 (Extrapolation) 警告の検証
    # ----------------------------------------------------------------
    println("\n[TEST 5] Verifying Extrapolation Warning...")
    # 明らかに学習範囲 [0.1, 0.9] をはみ出る異常値パラメータ
    mu_extrap = fill(2.5, 16)
    println("  -> Calling evaluate_rom with out-of-bounds parameter. A warning should trigger below:")
    ROMInterpolator.evaluate_rom(loaded_rom, basis, mean_field, mu_extrap)

    println("\n==================================================")
    println("         ALL TESTS COMPLETED SUCCESSFULLY!")
    println("==================================================")
    println("Please check the generated visualization results in: ")
    println("  -> [Workspace] rom_plots/ (Report & Base snapshots)")
    println("  -> [Workspace] verify_output/ (Fresh test results & comparisons)")

finally
    # 一時ファイルのクリーンアップ
    rm("config.json", force=true)
    rm("tsv_config.json", force=true)
end
