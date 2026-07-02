using Test
using Printf
using JLD2

# 1. 依存モジュールのロード
println(">>> 1. Loading core modules...")
push!(LOAD_PATH, abspath("H2-main-ext/src"))
using modelA
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

# 出力ディレクトリの設定 (rom_plots に直接保存)
out_dir = "rom_plots"
mkpath(out_dir)

# 格子サイズ設定 (FVM)
NX, NY, NZ = 60, 60, 30

println("\n==================================================")
println("   ROM Manual Shift Verification Playground")
println("==================================================")

try
    # ----------------------------------------------------------------
    # 1. パラメータケースの定義 (TSV移動量)
    # ----------------------------------------------------------------
    
    # 基本の16本TSVの座標リスト (H2-main_TSV_Opt/tsv_config.json からのコピー)
    base_coords = [
        [0.3e-3, 0.3e-3], [0.3e-3, 0.5e-3], [0.3e-3, 0.7e-3], [0.3e-3, 0.9e-3],
        [0.5e-3, 0.3e-3], [0.5e-3, 0.5e-3], [0.5e-3, 0.7e-3], [0.5e-3, 0.9e-3],
        [0.7e-3, 0.3e-3], [0.7e-3, 0.5e-3], [0.7e-3, 0.7e-3], [0.7e-3, 0.9e-3],
        [0.9e-3, 0.3e-3], [0.9e-3, 0.5e-3], [0.9e-3, 0.7e-3], [0.9e-3, 0.9e-3]
    ]

    # 設計パラメータ μ として、移動量 (shift) を 1次元パラメータとする
    # Case 1: 移動量 0.0 um (オリジナル)
    shift1 = 0.0
    # Case 2: 移動量 40.0 um (ずらしたモデル)
    shift2 = 40.0e-6

    shifts = [shift1, shift2]
    snapshot_files = String[]
    
    for (idx, shift) in enumerate(shifts)
        snap_path = joinpath(out_dir, "snap_shift_$(idx).jld2")
        push!(snapshot_files, snap_path)
        println("\n[Case $(idx)] Running FVM for TSV Shift = $(shift*1e6) um...")
        
        # シフトを加えた座標リストを作成
        shifted_coords = [[c[1] + shift, c[2] + shift] for c in base_coords]
        
        # tsv_config.json の動的生成 (manualモード)
        tsv_json = """
        {
          "tsv_mode": "manual",
          "tsv_radius": 2.0e-5,
          "manual_coordinates": $(shifted_coords)
        }
        """
        write("tsv_config.json", tsv_json)
        
        # 物理構造用の config.json (退避されたレガシーファイルからコピー)
        cp("legacy/H2-main_TSV_Opt/config.json", "config.json", force=true)
        
        # FVM実行と保存 (設計パラメータとして 1次元の [shift] を渡す)
        q3d(NX, NY, NZ, "cg", "gs"; epsilon=1e-3, par="sequential", is_steady=true, snapshot_path=snap_path, mu=[shift])
        
        @assert isfile(snap_path) "Snapshot file not generated!"
        
        # スナップショットの可視化 (温度スケール 300K - 360K に固定)
        ValidationPlot.plot_snapshot_xy(snap_path; zc=0.33e-3, out_dir=out_dir, clims=(300.0, 360.0))
        println("  -> Visualized snapshot $(idx) to: $(out_dir)/snap_shift_$(idx)_sidebyside_xy.png")
    end
    
    # ----------------------------------------------------------------
    # 2. POD 基底抽出
    # ----------------------------------------------------------------
    println("\n>>> 2. Performing POD Decomposition...")
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
    
    # ----------------------------------------------------------------
    # 3. ROM の学習・保存
    # ----------------------------------------------------------------
    println("\n>>> 3. Training ROM Model...")
    Mu = reshape(shifts, 1, 2) # (1次元パラメータ x 2サンプル) の行列
    rom_file = joinpath(out_dir, "shift_rom_model.jld2")
    
    rom_model = ROMInterpolator.train_rom(Mu, coeffs, rom_file; epsilon=1e-5, lambda=1e-6)
    loaded_rom = ROMInterpolator.load_rom_model(rom_file)
    println("  -> ROM Model saved & loaded.")
    
    # ----------------------------------------------------------------
    # 4. 未知のパラメータ（中間量 20 um シフト）に対するROMの予測と検証
    # ----------------------------------------------------------------
    shift_test = 20.0e-6
    println("\n>>> 4. Evaluating ROM Prediction on Shift = $(shift_test*1e6) um (Unknown Parameter)...")
    
    # 厳密解の生成
    ref_snap = joinpath(out_dir, "ref_shift_test.jld2")
    shifted_coords_test = [[c[1] + shift_test, c[2] + shift_test] for c in base_coords]
    tsv_json_test = """
    {
      "tsv_mode": "manual",
      "tsv_radius": 2.0e-5,
      "manual_coordinates": $(shifted_coords_test)
    }
    """
    write("tsv_config.json", tsv_json_test)
    q3d(NX, NY, NZ, "cg", "gs"; epsilon=1e-3, par="sequential", is_steady=true, snapshot_path=ref_snap, mu=[shift_test])
    
    ref_data = JLD2.load(ref_snap)
    theta_fvm = vec(ref_data["theta"])
    
    # ROM による高速予測
    theta_rom = ROMInterpolator.evaluate_rom(loaded_rom, basis, mean_field, [shift_test])
    
    # 精度検証 (L2誤差)
    l2_err = ROMValidator.calculate_l2_error(theta_fvm, theta_rom)
    tmax_err = ROMValidator.calculate_tmax_error(theta_fvm, theta_rom)
    
    @printf("  -> Relative L2 Error   : %.6e\n", l2_err)
    @printf("  -> Tmax Absolute Error : %.6f [K]\n", tmax_err)
    
    # 比較プロットの生成 (絶対誤差マップ含む)
    Z_faces = ref_data["z_faces"]
    ValidationPlot.plot_rom_comparison(theta_fvm, theta_rom, size(ref_data["theta"]), Z_faces; zc=0.33e-3, out_dir=out_dir, clims=(300.0, 360.0))
    println("  -> Visualized comparison plot to: $(out_dir)/rom_fvm_comparison_xy.png")
    
    println("\n==================================================")
    println("         ALL TESTS COMPLETED SUCCESSFULLY!")
    println("==================================================")

finally
    # 一時ファイルのクリーンアップ
    rm("config.json", force=true)
    rm("tsv_config.json", force=true)
end
