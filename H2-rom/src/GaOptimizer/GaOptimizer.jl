module GaOptimizer

using JLD2

# Shared H2MainExt module to avoid duplicate includes and type mismatches
module H2MainExt
    const SRC_DIR = abspath(joinpath(@__DIR__, "../../../H2-main-ext/src"))
    include(joinpath(SRC_DIR, "ConfigLoader/ConfigLoader.jl"))
    using .ConfigLoader
    include(joinpath(SRC_DIR, "ComponentGenerator/ComponentGenerator.jl"))
    using .ComponentGenerator
end

try
    using ROMInterpolator
catch
    if !isdefined(Main, :ROMInterpolator)
        path = joinpath(@__DIR__, "..", "ROMInterpolator", "ROMInterpolator.jl")
        Main.eval(:(include($path)))
    end
    using Main.ROMInterpolator
end

try
    using PODEngine
catch
    if !isdefined(Main, :PODEngine)
        path = joinpath(@__DIR__, "..", "PODEngine", "PODEngine.jl")
        Main.eval(:(include($path)))
    end
    using Main.PODEngine
end

include("Types.jl")
include("ConstraintManager.jl")
include("ReliabilityManager.jl")
include("Engine.jl")

export Individual, OptimizationState, OptimizationConfig, ConstraintManager, ReliabilityManager
export crossover, mutate!, evaluate_population!, tournament_select, select_next_generation
export run_optimization

"""
    run_optimization(model_config::H2MainExt.ConfigLoader.ModelConfig, rom_model, basis::Matrix{Float64}, mean_field::Vector{Float64}; save_history::Bool=true, history_file::String="opt_history.jld2")

Orchestrate the genetic algorithm optimization loop.
"""
function run_optimization(model_config::H2MainExt.ConfigLoader.ModelConfig, rom_model, basis::Matrix{Float64}, mean_field::Vector{Float64};
                          save_history::Bool=true, history_file::String="opt_history.jld2",
                          run_final_val::Bool=true, report_file::String="final_validation_report.txt")
    # Load GA configuration
    ga_settings = model_config.tsv.ga
    if ga_settings === nothing
        error("GA settings not found in ModelConfig")
    end
    opt_config = OptimizationConfig(ga_settings)

    # Determine genotype length (gx * gy)
    gx = 1
    gy = 1
    rho_cell_max = 1.0
    if model_config.tsv.mode == :density && model_config.tsv.density !== nothing
        gx = model_config.tsv.density.gx
        gy = model_config.tsv.density.gy
        rho_cell_max = model_config.tsv.density.rho_cell_max
    end
    n = gx * gy

    # 1. Initialize population
    population = Vector{Individual}(undef, opt_config.n_pop)
    for i in 1:opt_config.n_pop
        mu = rand(n) .* rho_cell_max
        ConstraintManager.adjust_constraints!(mu, model_config)
        population[i] = Individual(mu)
    end

    # Evaluate initial population fitness
    for ind in population
        ind.fitness = ReliabilityManager.get_fitness(ind.mu, rom_model, basis, mean_field, model_config)
    end

    state = OptimizationState(population)
    
    # Record generation 0 best
    best_idx = argmin(i -> population[i].fitness, eachindex(population))
    state.best_individual = Individual(
        copy(population[best_idx].mu),
        population[best_idx].fitness,
        population[best_idx].is_fvm_verified,
        population[best_idx].extrapolation_score
    )
    push!(state.history, state.best_individual.fitness)

    println("Generation 0: Best Fitness = $(state.best_individual.fitness)")

    # 2. GA loop
    for gen in 1:opt_config.n_gen
        # Generate offspring
        next_pop = select_next_generation(state, opt_config, model_config)
        
        # Evaluate offspring
        for ind in next_pop
            if ind.fitness == Inf
                ind.fitness = ReliabilityManager.get_fitness(ind.mu, rom_model, basis, mean_field, model_config)
            end
        end
        
        state.population = next_pop
        state.generation = gen
        
        # Update best individual
        gen_best_idx = argmin(i -> state.population[i].fitness, eachindex(state.population))
        if state.population[gen_best_idx].fitness < state.best_individual.fitness
            state.best_individual = Individual(
                copy(state.population[gen_best_idx].mu),
                state.population[gen_best_idx].fitness,
                state.population[gen_best_idx].is_fvm_verified,
                state.population[gen_best_idx].extrapolation_score
            )
        end
        push!(state.history, state.best_individual.fitness)
        
        println("Generation $(gen)/$(opt_config.n_gen): Best Fitness = $(state.best_individual.fitness)")
    end

    # 3. FVM Revalidation for elites
    sorted_pop = sort(state.population, by = ind -> ind.fitness)
    elite_count = min(opt_config.n_elite, length(sorted_pop))
    elites = sorted_pop[1:elite_count]
    
    ReliabilityManager.verify_elites(elites, rom_model, basis, mean_field, model_config)
    
    # Re-evaluate best individual after FVM revalidation
    final_best_idx = argmin(i -> state.population[i].fitness, eachindex(state.population))
    if state.population[final_best_idx].fitness < state.best_individual.fitness
        state.best_individual = Individual(
            copy(state.population[final_best_idx].mu),
            state.population[final_best_idx].fitness,
            state.population[final_best_idx].is_fvm_verified,
            state.population[final_best_idx].extrapolation_score
        )
    end

    # 4. Save history to JLD2
    if save_history
        dir = dirname(history_file)
        if !isempty(dir) && !isdir(dir)
            mkpath(dir)
        end
        JLD2.save(history_file, Dict(
            "generation" => state.generation,
            "best_fitness" => state.best_individual.fitness,
            "history" => state.history,
            "best_mu" => state.best_individual.mu
        ))
        println("Saved optimization history to $(history_file)")
    end

    # 5. Final Validation Flow (Requirement 4)
    if run_final_val
        println("Starting final validation flow...")
        best_mu = state.best_individual.mu
        
        # 5.1 FVM simulation for the best individual
        tmax_fvm = ReliabilityManager.solve_thermal_fvm(best_mu, model_config)
        
        # 5.2 ROM prediction for the best individual
        theta_rom = ROMInterpolator.evaluate_rom(rom_model, basis, mean_field, best_mu)
        tmax_rom = ROMInterpolator.get_tmax(theta_rom)
        
        # 5.3 Calculate comparison error
        abs_error = abs(tmax_fvm - tmax_rom)
        
        # 5.4 Coordinate expansion to get real TSV coordinates
        if model_config.tsv.density !== nothing
            model_config.tsv.density.mu .= best_mu
        end
        pts = H2MainExt.ComponentGenerator.Layout.expand_coordinates(model_config.tsv, model_config.lx, model_config.ly)
        
        # Write report
        write_summary_report(report_file, state.best_individual, tmax_rom, tmax_fvm, abs_error, pts)
    end

    return state
end

"""
    run_optimization(config_path::String, tsv_config_path::String, rom_model_path::String, pod_model_path::String; save_history::Bool=true, history_file::String="opt_history.jld2", run_final_val::Bool=true, report_file::String="final_validation_report.txt")

Orchestrate the genetic algorithm optimization loop using file paths.
"""
function run_optimization(config_path::String, tsv_config_path::String, rom_model_path::String, pod_model_path::String;
                          save_history::Bool=true, history_file::String="opt_history.jld2",
                          run_final_val::Bool=true, report_file::String="final_validation_report.txt")
    # Load configuration files
    model_config = H2MainExt.ConfigLoader.load_config(config_path, tsv_config_path)
    
    # Load ROM model
    rom_model = ROMInterpolator.load_rom_model(rom_model_path)
    
    # Load POD model
    pod_model = load_pod_model(pod_model_path)
    
    basis = pod_model.basis
    mean_field = pod_model.mean_field
    
    return run_optimization(model_config, rom_model, basis, mean_field;
                            save_history=save_history, history_file=history_file,
                            run_final_val=run_final_val, report_file=report_file)
end

"""
    write_summary_report(report_file::String, best_ind::Individual, tmax_rom::Float64, tmax_fvm::Float64, abs_error::Float64, pts::Vector)

Write a validation report including max temperatures, real TSV coordinates, and ROM/FVM error.
"""
function write_summary_report(report_file::String, best_ind::Individual, tmax_rom::Float64, tmax_fvm::Float64, abs_error::Float64, pts::Vector)
    dir = dirname(report_file)
    if !isempty(dir) && !isdir(dir)
        mkpath(dir)
    end
    open(report_file, "w") do io
        println(io, "=== Final Validation Report ===")
        println(io, "Optimization Status: COMPLETED")
        println(io, "")
        println(io, "Best Individual Genotype (mu):")
        println(io, best_ind.mu)
        println(io, "")
        println(io, "ROM Predicted Max Temperature: ", tmax_rom)
        println(io, "FVM Simulated Max Temperature: ", tmax_fvm)
        println(io, "Absolute Error: ", abs_error)
        println(io, "")
        println(io, "Real TSV Coordinates (Count: ", length(pts), "):")
        for (i, p) in enumerate(pts)
            println(io, "  $i: (x=$(p.x), y=$(p.y))")
        end
    end
    println("Saved final validation report to $(report_file)")
end

end # module
