using Test

if !isdefined(Main, :GaOptimizer)
    include("../src/GaOptimizer/GaOptimizer.jl")
end
if !isdefined(Main, :ROMInterpolator)
    include("../src/ROMInterpolator/ROMInterpolator.jl")
end

using .GaOptimizer: Individual, OptimizationState, OptimizationConfig
using .GaOptimizer: evaluate_population!, tournament_select, select_next_generation
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

@testset "GA Engine Selection and Evaluation Tests" begin
    # 1. Setup RBFInterpolator
    epsilon = 0.5
    rbf = RBFInterpolator(epsilon)
    X = [1.0 2.0 3.0; 
         4.0 5.0 6.0]
    Y = [10.0 20.0 30.0; 
         40.0 50.0 60.0; 
         70.0 80.0 90.0]
    fit!(rbf, X, Y)
    
    basis = [1.0 0.0 0.0;
             0.0 1.0 0.0;
             0.0 0.0 1.0;
             0.1 0.2 0.3]
    mean_field = [0.1, 0.2, 0.3, 0.4]
    
    # 2. Setup Model and Optimization Config
    model_config = make_test_model_config(
        mu=[0.5, 0.5, 0.5, 0.5],
        n_max=20,
        rho_cell_max=0.8,
        prohibited_cells=[(1, 2)]
    )
    
    opt_config = OptimizationConfig(
        6,     # n_pop (population size)
        10,    # n_gen
        0.8,   # cx_rate
        0.1,   # mut_rate
        2      # n_elite
    )

    @testset "Population Evaluation" begin
        population = [
            Individual([1.0, 4.0]),
            Individual([2.0, 5.0]),
            Individual([3.0, 6.0])
        ]
        
        # Initially fitness is Inf
        @test all(ind.fitness == Inf for ind in population)
        
        # Run evaluation
        evaluate_population!(population, rbf, basis, mean_field)
        
        # Fitness should be updated to a finite float
        @test all(ind.fitness != Inf for ind in population)
        @test all(ind.fitness isa Float64 for ind in population)
        
        # Check specific expected value for the first individual [1.0, 4.0]
        # predict([1.0, 4.0]) should return Y[:, 1] = [10.0, 40.0, 70.0]
        # reconstruct_field([10.0, 40.0, 70.0], basis, mean_field)
        # = [0.1, 0.2, 0.3, 0.4] + [10.0, 40.0, 70.0, 1.0*10.0 + 2.0*40.0 + 3.0*70.0 * 0.1?]
        # basis is 4x3:
        # [1.0 0.0 0.0]
        # [0.0 1.0 0.0]
        # [0.0 0.0 1.0]
        # [0.1 0.2 0.3]
        # basis * coeffs = [10.0, 40.0, 70.0, 1.0 + 8.0 + 21.0] = [10.0, 40.0, 70.0, 30.0]
        # + mean_field = [10.1, 40.2, 70.3, 30.4]
        # get_tmax should be 70.3
        @test population[1].fitness ≈ 70.3 atol=1e-3
    end

    @testset "Tournament Selection" begin
        # Lower fitness is better (minimize temperature)
        population = [
            Individual([1.0, 4.0], 150.0),
            Individual([2.0, 5.0], 50.0), # Best
            Individual([3.0, 6.0], 100.0)
        ]
        
        # Test tournament selection
        selected = [tournament_select(population, 3) for _ in 1:100]
        @test all(ind in population for ind in selected)
        
        # With size 3, the best individual (50.0) should always be selected
        # because the tournament size equals the population size, so it will always
        # contain the best individual.
        @test all(ind.fitness == 50.0 for ind in selected)
    end

    @testset "Next Generation Selection and Elite Preservation" begin
        population = [
            Individual([1.0, 1.0, 0.0, 1.0], 150.0),
            Individual([0.5, 0.5, 0.0, 0.5], 50.0),  # Best 1
            Individual([0.8, 0.8, 0.0, 0.8], 80.0),  # Best 2
            Individual([0.2, 0.2, 0.0, 0.2], 120.0),
            Individual([0.3, 0.3, 0.0, 0.3], 200.0),
            Individual([0.4, 0.4, 0.0, 0.4], 90.0)
        ]
        
        state = OptimizationState(0, nothing, population, Float64[])
        
        # Next generation
        next_pop = select_next_generation(state, opt_config, model_config)
        
        @test length(next_pop) == opt_config.n_pop
        
        # Verify elite preservation: the best two individuals (50.0 and 80.0)
        # must survive exactly (same mu, same fitness).
        elites = filter(ind -> ind.fitness in [50.0, 80.0], next_pop)
        @test length(elites) >= 2
        @test any(ind.mu ≈ [0.5, 0.5, 0.0, 0.5] && ind.fitness == 50.0 for ind in elites)
        @test any(ind.mu ≈ [0.8, 0.8, 0.0, 0.8] && ind.fitness == 80.0 for ind in elites)
        
        # Other individuals should be adjusted constraints and initialized
        # (their fitness might be Inf if mutated, or they might be copied from parents)
        for ind in next_pop
            # Prohibited cell (index 3) must be 0.0 because child constraints are enforced
            @test ind.mu[3] == 0.0
            @test all(ind.mu .<= 0.8)
        end
    end
end
