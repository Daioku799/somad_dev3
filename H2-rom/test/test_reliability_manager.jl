using Test
using JLD2

if !isdefined(Main, :GaOptimizer)
    include("../src/GaOptimizer/GaOptimizer.jl")
end
if !isdefined(Main, :ROMInterpolator)
    include("../src/ROMInterpolator/ROMInterpolator.jl")
end

# We will implement ReliabilityManager inside GaOptimizer module,
# so once integrated, we can import it from GaOptimizer.
# For TDD RED phase, this import might fail if the module isn't integrated yet.
using .GaOptimizer: ReliabilityManager
using .GaOptimizer.ReliabilityManager: is_reliable, get_fitness, solve_thermal_fvm
using .GaOptimizer.H2MainExt.ConfigLoader: ModelConfig, TSVConfig, DensityMapConfig, ManufacturingConfig, Material, Layer
using .ROMInterpolator: RBFInterpolator, fit!, evaluate_rom, get_tmax

# Helper to construct ModelConfig
function make_test_model_config(; lx=1.2e-3, ly=1.2e-3, gx=2, gy=2, mu=[1.0, 1.0, 1.0, 1.0], n_max=50, p_min=0.1e-3, rho_cell_max=1.0, prohibited_cells=Tuple{Int, Int}[])
    density = DensityMapConfig(
        gx,
        gy,
        mu,
        0,      # n_min
        n_max,  # n_max
        rho_cell_max,
        prohibited_cells
    )
    mfg = ManufacturingConfig(
        0.02e-3, # d_tsv
        p_min,   # p_min
        1.0,     # ar_min
        10.0     # ar_max
    )
    tsv = TSVConfig(
        :density,
        Tuple{Float64, Float64}[],
        0.01e-3,
        0.1e-3,
        density,
        mfg,
        nothing
    )
    return ModelConfig(
        Material[],
        Layer[],
        tsv,
        lx,
        ly,
        0.0,
        0.0,
        0.0,
        0.0,
        false,
        "",
        nothing,
        1e-6,
        100
    )
end

@testset "ReliabilityManager Tests" begin
    # 1. Setup RBFInterpolator
    epsilon = 0.5
    rbf = RBFInterpolator(epsilon)
    # 2 inputs, 3 samples
    X = [1.0 2.0 3.0; 
         4.0 5.0 6.0]
    # 3 modes, 3 samples
    Y = [10.0 20.0 30.0; 
         40.0 50.0 60.0; 
         70.0 80.0 90.0]
    fit!(rbf, X, Y)
    
    basis = [1.0 0.0 0.0;
             0.0 1.0 0.0;
             0.0 0.0 1.0;
             0.1 0.2 0.3]
    mean_field = [0.1, 0.2, 0.3, 0.4]
    
    config = make_test_model_config()

    @testset "is_reliable test" begin
        # Within bounds [1.0, 3.0] x [4.0, 6.0]
        @test is_reliable(rbf, [2.0, 5.0]) == true
        @test is_reliable(rbf, [1.0, 4.0]) == true
        @test is_reliable(rbf, [3.0, 6.0]) == true

        # Outside bounds
        @test is_reliable(rbf, [0.5, 5.0]) == false # dimension 1 too small
        @test is_reliable(rbf, [3.5, 5.0]) == false # dimension 1 too large
        @test is_reliable(rbf, [2.0, 3.5]) == false # dimension 2 too small
        @test is_reliable(rbf, [2.0, 6.5]) == false # dimension 2 too large
    end

    @testset "get_fitness test (Reliable vs Extrapolated)" begin
        # Case A: Within bounds
        mu_in = [2.0, 5.0]
        # Evaluate ROM directly to get the reference temperature
        theta_in = evaluate_rom(rbf, basis, mean_field, mu_in)
        tmax_ref = get_tmax(theta_in)
        
        # get_fitness should return exact Tmax
        @test get_fitness(mu_in, rbf, basis, mean_field, config) ≈ tmax_ref

        # Case B: Outside bounds (Extrapolation)
        mu_out = [0.5, 5.0]
        theta_out = evaluate_rom(rbf, basis, mean_field, mu_out)
        tmax_out_ref = get_tmax(theta_out)
        
        # get_fitness should return Tmax + penalty (default 1000.0)
        # and it should trigger warning logs from both ReliabilityManager and ROMInterpolator
        fit_val = @test_logs (:warn, r"Extrapolation detected") (:warn, r"outside the training bounds") get_fitness(mu_out, rbf, basis, mean_field, config)
        @test fit_val ≈ tmax_out_ref + 1000.0

        # Custom penalty
        fit_val_custom = @test_logs (:warn, r"Extrapolation detected") (:warn, r"outside the training bounds") get_fitness(mu_out, rbf, basis, mean_field, config; penalty=500.0)
        @test fit_val_custom ≈ tmax_out_ref + 500.0
    end

    @testset "solve_thermal_fvm test (fallback behavior)" begin
        # Since solver setup is not fully configured, solve_thermal_fvm should return a float (like Inf) on failure/missing solver instead of crashing.
        mu = [2.0, 5.0]
        fvm_val = solve_thermal_fvm(mu, config)
        @test fvm_val isa Float64
    end

    @testset "verify_elites test" begin
        # ダミーの q3d を上書き定義 (本物と完全に同じシグネチャでディスパッチを奪う)
        Main.eval(:(function q3d(NX::Int, NY::Int, NZ::Int,
                 solver::String="sor", smoother::String="";
                 epsilon::Float64=1.0e-6, par::String="thread", is_steady::Bool=false,
                 snapshot_path::String="", mu::Vector{Float64}=Float64[])
            if !isempty(snapshot_path)
                JLD2.save(snapshot_path, "theta", [55.0])
            end
        end))

        # 一時ファイル config.json, tsv_config.json の作成
        write("config.json", "{}")
        write("tsv_config.json", "{}")

        try
            # テストデータ
            mu = [2.0, 5.0]
            theta_rom = evaluate_rom(rbf, basis, mean_field, mu)
            tmax_rom = get_tmax(theta_rom)
            
            # 初期個体 (FVM検証前)
            ind = GaOptimizer.Individual(mu, tmax_rom)
            
            # 1. enable_fvm_revalidation = false の場合 (デフォルト)
            # FVM再検証は行われず、適合度は変更されず、is_fvm_verified は false のままであること
            elites = [ind]
            result_elites = ReliabilityManager.verify_elites(elites, rbf, basis, mean_field, config; enable_fvm_revalidation=false)
            @test result_elites[1].is_fvm_verified == false
            @test result_elites[1].fitness ≈ tmax_rom

            # 2. enable_fvm_revalidation = true かつ enable_error_warning = false の場合
            # FVM再検証が行われ、適合度が FVM の結果 (55.0) に更新されるが、警告ログは出力されないこと
            elites_no_warn = [GaOptimizer.Individual(mu, tmax_rom)]
            log_pattern = r"ROM vs FVM"
            
            result_elites_true = @test_logs (:info, log_pattern) ReliabilityManager.verify_elites(
                elites_no_warn, rbf, basis, mean_field, config; enable_error_warning=false
            )
            @test result_elites_true[1].is_fvm_verified == true
            @test result_elites_true[1].fitness ≈ 55.0

            # 3. デフォルト設定 (引数なし：両フラグ=true, 閾値=5.0) で誤差が閾値を超える場合
            # ROM予測は約 80.3 (rbf評価)、FVM実測は 55.0 なので絶対誤差は約 25.3
            # デフォルト閾値 5.0 を超えるため、警告ログ (@warn) が自動的に出力されること
            elites_warn = [GaOptimizer.Individual(mu, tmax_rom)]
            warn_pattern = r"prediction error exceeds threshold"
            @test_logs (:info, log_pattern) (:warn, warn_pattern) ReliabilityManager.verify_elites(
                elites_warn, rbf, basis, mean_field, config
            )

            # 4. デフォルト設定 (enable_error_warning=true) で、error_threshold=30.0 を指定して誤差が閾値以下の場合は警告が出ないこと
            # 絶対誤差 約25.3 は閾値 30.0 以下なので警告は出ないはず
            elites_nowarn = [GaOptimizer.Individual(mu, tmax_rom)]
            @test_logs (:info, log_pattern) ReliabilityManager.verify_elites(
                elites_nowarn, rbf, basis, mean_field, config; error_threshold=30.0
            )
            
        finally
            # 一時ファイルの削除
            rm("config.json", force=true)
            rm("tsv_config.json", force=true)
        end
    end
end
