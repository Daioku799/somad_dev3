using Test

if !isdefined(Main, :GaOptimizer)
    include("../src/GaOptimizer/GaOptimizer.jl")
end

using .GaOptimizer: Individual, OptimizationConfig
# These might not exist yet, causing a compilation or loading error (RED)
using .GaOptimizer: crossover, mutate!

using .GaOptimizer.H2MainExt.ConfigLoader: ModelConfig, TSVConfig, DensityMapConfig, ManufacturingConfig, Material, Layer

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

@testset "GA Engine Operators Tests" begin
    model_config = make_test_model_config(
        mu=[0.5, 0.5, 0.5, 0.5],
        n_max=20, # strict constraint
        rho_cell_max=0.8,
        prohibited_cells=[(1, 2)]
    )
    
    # 2x2 cells, capacities matrix
    # Total capacities: get_cell_capacities(config.tsv, config.lx, config.ly)
    # Total TSV capacity is 25 per cell.
    # index 3 (which corresponds to (1,2) in 2x2 column major) is prohibited.
    
    opt_config = OptimizationConfig(
        10,    # n_pop
        10,    # n_gen
        0.8,   # cx_rate
        1.0,   # mut_rate (always mutate for test)
        2      # n_elite
    )

    @testset "Crossover (BLX-alpha)" begin
        parent1 = Individual([0.2, 0.3, 0.0, 0.4])
        parent2 = Individual([0.4, 0.1, 0.0, 0.2])
        
        # Perform crossover
        child1, child2 = crossover(parent1, parent2, opt_config, model_config)
        
        @test typeof(child1) == Individual
        @test typeof(child2) == Individual
        
        # Check that constraints are satisfied
        # 1. Prohibited cell (index 3) is 0
        @test child1.mu[3] == 0.0
        @test child2.mu[3] == 0.0
        
        # 2. Maximum cell density <= 0.8
        @test all(child1.mu .<= 0.8)
        @test all(child2.mu .<= 0.8)
        
        # 3. Total TSVs <= 20
        # Capacities: each cell is 25
        sum_tsv1 = sum(round(Int, child1.mu[i] * 25) for i in 1:4)
        sum_tsv2 = sum(round(Int, child2.mu[i] * 25) for i in 1:4)
        @test sum_tsv1 <= 20
        @test sum_tsv2 <= 20
        
        # 4. BLX-alpha bounds check (alpha=0.5)
        # For index 1: parent1 is 0.2, parent2 is 0.4.
        # Range: [0.2 - 0.5*0.2, 0.4 + 0.5*0.2] = [0.1, 0.5]
        # Since child1 and child2 are scaled by adjust_constraints!, we just check if
        # values are valid numbers and not equal to initial unscaled random arrays.
        # But we can verify before constraints scaling (or at least check that they are populated).
        @test all(!isnan, child1.mu)
        @test all(!isnan, child2.mu)
    end

    @testset "Gaussian Mutation" begin
        # Create an individual with valid starting values
        ind = Individual([0.2, 0.3, 0.0, 0.4])
        ind.fitness = 100.0  # Set dummy fitness
        
        # Mutate (in-place)
        mutated_ind = mutate!(ind, opt_config, model_config)
        
        # Verify it returns the mutated individual (or same reference)
        @test mutated_ind === ind
        
        # Check fitness is reset to Inf
        @test mutated_ind.fitness === Inf
        
        # Check value is modified
        # (Since mutation rate is 1.0, elements should change, though index 3 is prohibited and will remain 0)
        @test mutated_ind.mu[3] == 0.0
        @test mutated_ind.mu[1] != 0.2 || mutated_ind.mu[2] != 0.3 || mutated_ind.mu[4] != 0.4
        
        # Check constraints are satisfied
        @test all(mutated_ind.mu .<= 0.8)
        sum_tsv = sum(round(Int, mutated_ind.mu[i] * 25) for i in 1:4)
        @test sum_tsv <= 20
    end
end
