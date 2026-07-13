using Test

if !isdefined(Main, :GaOptimizer)
    include("../src/GaOptimizer/GaOptimizer.jl")
end

using .GaOptimizer.ConstraintManager: adjust_constraints!

using .GaOptimizer.H2MainExt.ConfigLoader: ModelConfig, Material, Layer, TSVConfig, DensityMapConfig, ManufacturingConfig

# Helper to construct ModelConfig
function make_test_model_config(; lx=1.2e-3, ly=1.2e-3, gx=2, gy=2, mu=[1.0, 1.0, 1.0, 1.0], n_max=50, p_min=0.1e-3, rho_cell_max=1.0, prohibited_cells=Tuple{Int, Int}[])
    density = DensityMapConfig(
        gx,
        gy,
        mu,
        0,      # n_min
        n_max,  # n_max (N_limit)
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

@testset "ConstraintManager Tests" begin
    # Test case 1: No violation
    config = make_test_model_config(mu=[0.1, 0.2, 0.3, 0.4], n_max=50)
    mu = [0.1, 0.2, 0.3, 0.4]
    adjust_constraints!(mu, config)
    @test mu ≈ [0.1, 0.2, 0.3, 0.4]

    # Test case 2: Clamping [0.0, 1.0] (default rho_cell_max is 1.0)
    config = make_test_model_config(mu=[1.5, -0.5, 0.5, 1.0], n_max=100)
    mu = [1.5, -0.5, 0.5, 1.0]
    adjust_constraints!(mu, config)
    @test mu ≈ [1.0, 0.0, 0.5, 1.0]

    # Test case 3: Clamping with rho_cell_max (e.g. 0.6)
    config = make_test_model_config(mu=[1.0, 0.8, -0.2, 0.5], n_max=100, rho_cell_max=0.6)
    mu = [1.0, 0.8, -0.2, 0.5]
    adjust_constraints!(mu, config)
    @test mu ≈ [0.6, 0.6, 0.0, 0.5]

    # Test case 4: Prohibited cells (forbidden zones)
    # gx = 2, gy = 2. Cell index (1, 2) should be mapped to flat index (2 - 1) * 2 + 1 = 3 (column-major)
    config = make_test_model_config(mu=[0.8, 0.8, 0.8, 0.8], n_max=100, prohibited_cells=[(1, 2)])
    mu = [0.8, 0.8, 0.8, 0.8]
    adjust_constraints!(mu, config)
    @test mu[3] == 0.0
    @test mu[1] == 0.8
    @test mu[2] == 0.8
    @test mu[4] == 0.8

    # Test case 5: Scaling when total TSVs exceed limit
    config = make_test_model_config(mu=[1.0, 1.0, 1.0, 1.0], n_max=50)
    mu = [1.0, 1.0, 1.0, 1.0]
    adjust_constraints!(mu, config)
    
    # Check that scaled values * capacities sum up to <= N_limit (50)
    capacities = [25, 25, 25, 25] # 2x2 cells
    sum_tsvs = sum(round(Int, mu[i] * capacities[i]) for i in 1:4)
    @test sum_tsvs <= 50
    @test all(0.0 .<= mu .<= 1.0)

    # Test case 6: Combined Clamping, Prohibited Cells, and Scaling
    # gx = 2, gy = 2. N_limit = 20. rho_cell_max = 0.8. prohibited_cells = [(2, 1)] -> index 2.
    # Input mu: [1.2, 1.2, 1.2, 1.2]
    # Expected after step 1 & 2: [0.8, 0.0, 0.8, 0.8]
    # Then scaling applied to [0.8, 0.0, 0.8, 0.8] to satisfy sum(round(Int, mu_i * 25)) <= 20
    config = make_test_model_config(mu=[1.2, 1.2, 1.2, 1.2], n_max=20, rho_cell_max=0.8, prohibited_cells=[(2, 1)])
    mu = [1.2, 1.2, 1.2, 1.2]
    adjust_constraints!(mu, config)
    @test mu[2] == 0.0
    @test all(0.0 .<= mu .<= 0.8)
    sum_tsvs_combined = sum(round(Int, mu[i] * capacities[i]) for i in 1:4)
    @test sum_tsvs_combined <= 20

    # Test case 7: Resampling when input mu is all 0.0
    config = make_test_model_config(mu=[0.0, 0.0, 0.0, 0.0], n_max=20, rho_cell_max=0.8)
    mu = [0.0, 0.0, 0.0, 0.0]
    adjust_constraints!(mu, config)
    @test !all(x -> x < 1e-9, mu)
    @test all(0.0 .<= mu .<= 0.8)
    sum_tsvs = sum(round(Int, mu[i] * capacities[i]) for i in 1:4)
    @test sum_tsvs <= 20

    # Test case 8: Resampling when input mu contains NaN
    config = make_test_model_config(mu=[NaN, 0.5, 0.5, 0.5], n_max=20, rho_cell_max=0.8)
    mu = [NaN, 0.5, 0.5, 0.5]
    adjust_constraints!(mu, config)
    @test !any(isnan, mu)
    @test !all(x -> x < 1e-9, mu)
    @test all(0.0 .<= mu .<= 0.8)

    # Test case 9: Error throwing when no valid map can be generated (all cells prohibited)
    config = make_test_model_config(mu=[0.5, 0.5, 0.5, 0.5], n_max=20, prohibited_cells=[(1,1), (2,1), (1,2), (2,2)])
    mu = [0.5, 0.5, 0.5, 0.5]
    @test_throws ErrorException adjust_constraints!(mu, config)
end

