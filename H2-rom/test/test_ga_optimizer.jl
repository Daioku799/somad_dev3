using Test
using JLD2

if !isdefined(Main, :GaOptimizer)
    include("../src/GaOptimizer/GaOptimizer.jl")
end
if !isdefined(Main, :ROMInterpolator)
    include("../src/ROMInterpolator/ROMInterpolator.jl")
end

using .GaOptimizer: run_optimization, Individual, OptimizationState, OptimizationConfig
using .GaOptimizer.H2MainExt.ConfigLoader: ModelConfig, TSVConfig, DensityMapConfig, ManufacturingConfig, GASettings, Material, Layer
using .ROMInterpolator: RBFInterpolator, fit!

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
    ga = GASettings(
        10,     # n_pop
        5,      # n_gen (run 5 generations for fast test)
        0.8,    # cx_rate
        0.1,    # mut_rate
        2       # n_elite
    )
    tsv = TSVConfig(
        :density,
        Tuple{Float64, Float64}[],
        0.01e-3,
        0.1e-3,
        density,
        mfg,
        ga
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

@testset "GaOptimizer Main Integration Tests" begin
    # 1. Setup mock ROM model
    epsilon = 0.5
    rbf = RBFInterpolator(epsilon)
    # 4 inputs, 3 samples
    X = [0.1 0.5 0.8;
         0.2 0.4 0.6;
         0.3 0.3 0.7;
         0.1 0.2 0.3]
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
    
    config = make_test_model_config(mu=[0.5, 0.4, 0.3, 0.2])
    
    # Define a temporary history file path
    history_file = "test_opt_history.jld2"
    rm(history_file, force=true) # Ensure it does not exist
    
    try
        # Test Case 1: Flag save_history is OFF (default)
        # The history JLD2 file should not be created.
        state = run_optimization(config, rbf, basis, mean_field; save_history=false, history_file=history_file)
        
        @test state isa OptimizationState
        @test !isfile(history_file)
        
        # Test Case 2: Flag save_history is ON (explicitly true)
        # The history JLD2 file should be created and contain optimization progress data.
        state_saved = run_optimization(config, rbf, basis, mean_field; save_history=true, history_file=history_file)
        
        @test isfile(history_file)
        
        # Load and verify saved history
        saved_data = JLD2.load(history_file)
        @test haskey(saved_data, "generation")
        @test haskey(saved_data, "best_fitness")
        @test haskey(saved_data, "history")
        @test haskey(saved_data, "best_mu")
        
        @test saved_data["generation"] == config.tsv.ga.n_gen
        @test length(saved_data["history"]) == config.tsv.ga.n_gen + 1
        
        # Test Case 3: Optimization execution control verification
        # Optimization state fields should be properly set
        @test state_saved.generation == config.tsv.ga.n_gen
        @test length(state_saved.history) == config.tsv.ga.n_gen + 1
        @test state_saved.best_individual !== nothing
        @test state_saved.best_individual.fitness < Inf
        @test length(state_saved.best_individual.mu) == 4
        
        @testset "Path-based run_optimization overload" begin
            using JSON
            
            tmp_dir = mktempdir()
            config_path = joinpath(tmp_dir, "config.json")
            tsv_config_path = joinpath(tmp_dir, "tsv_config.json")
            rom_path = joinpath(tmp_dir, "rom_model.jld2")
            pod_path = joinpath(tmp_dir, "pod_model.jld2")
            
            config_data = Dict(
                "materials" => Dict(
                    "Silicon" => Dict("id" => 1, "λ" => 150.0, "ρ" => 2330.0, "C" => 700.0)
                ),
                "layers" => [
                    Dict("name" => "L1", "thickness" => 10e-6, "divisions" => 2, "grading" => 1.0),
                    Dict("name" => "L2", "thickness" => 10e-6, "divisions" => 2, "grading" => 1.0),
                    Dict("name" => "L3", "thickness" => 10e-6, "divisions" => 2, "grading" => 1.0),
                    Dict("name" => "L4", "thickness" => 10e-6, "divisions" => 2, "grading" => 1.0),
                    Dict("name" => "L5", "thickness" => 10e-6, "divisions" => 2, "grading" => 1.0),
                    Dict("name" => "L6", "thickness" => 10e-6, "divisions" => 2, "grading" => 1.0),
                    Dict("name" => "L7", "thickness" => 10e-6, "divisions" => 2, "grading" => 1.0),
                    Dict("name" => "L8", "thickness" => 10e-6, "divisions" => 2, "grading" => 1.0),
                    Dict("name" => "L9", "thickness" => 10e-6, "divisions" => 2, "grading" => 1.0),
                ],
                "dimensions" => Dict(
                    "h_tsv" => 100e-6,
                    "pg_dpth" => 5e-6,
                    "s_dpth" => 100e-6,
                    "d_ufill" => 50e-6,
                    "r_bump" => 30e-6
                ),
                "lx" => 1.2e-3,
                "ly" => 1.2e-3,
                "epsilon" => 1e-6,
                "max_iter" => 100
            )
            
            tsv_config_data = Dict(
                "tsv_mode" => "density",
                "tsv_radius" => 10e-6,
                "density_map" => Dict(
                    "gx" => 2,
                    "gy" => 2,
                    "mu" => [0.5, 0.4, 0.3, 0.2],
                    "n_min" => 0,
                    "n_max" => 50,
                    "rho_cell_max" => 1.0,
                    "prohibited_cells" => []
                ),
                "manufacturing" => Dict(
                    "d_tsv" => 20e-6,
                    "p_min" => 50e-6,
                    "ar_min" => 1.0,
                    "ar_max" => 10.0
                ),
                "ga_settings" => Dict(
                    "n_pop" => 10,
                    "n_gen" => 2,
                    "cx_rate" => 0.8,
                    "mut_rate" => 0.1,
                    "n_elite" => 2
                )
            )
            
            open(config_path, "w") do io
                JSON.print(io, config_data)
            end
            open(tsv_config_path, "w") do io
                JSON.print(io, tsv_config_data)
            end
            
            # Save ROM model
            using .ROMInterpolator: save_rom_model
            save_rom_model(rom_path, rbf)
            
            # Load and save POD model
            try
                using PODEngine
            catch
                if !isdefined(Main, :PODEngine)
                    pe_path = joinpath(@__DIR__, "..", "src", "PODEngine", "PODEngine.jl")
                    Main.eval(:(include($pe_path)))
                end
                using Main.PODEngine
            end
            
            pod_model = PODEngine.PODModel(
                basis,
                [1.0, 0.5, 0.1],
                zeros(3, 3),
                mean_field,
                ["snap1", "snap2", "snap3"],
                zeros(4, 3),
                Dict{String, Any}()
            )
            JLD2.save(pod_path, Dict("model" => pod_model))
            
            # Run optimization using file paths
            path_history_file = joinpath(tmp_dir, "path_opt_history.jld2")
            state_path = run_optimization(config_path, tsv_config_path, rom_path, pod_path; save_history=true, history_file=path_history_file)
            
            @test state_path isa OptimizationState
            @test state_path.generation == 2
            @test isfile(path_history_file)
            
            # Cleanup
            rm(tmp_dir, recursive=true, force=true)
        end
        
    finally
        # Clean up temporary history file
        rm(history_file, force=true)
    end
end
