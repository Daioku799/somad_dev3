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
                          save_history::Bool=true, history_file::String="opt_history.jld2")
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

    return state
end

"""
    run_optimization(config_path::String, tsv_config_path::String, rom_model_path::String, pod_model_path::String; save_history::Bool=true, history_file::String="opt_history.jld2")

Orchestrate the genetic algorithm optimization loop using file paths.
"""
function run_optimization(config_path::String, tsv_config_path::String, rom_model_path::String, pod_model_path::String;
                          save_history::Bool=true, history_file::String="opt_history.jld2")
    # Load configuration files
    model_config = H2MainExt.ConfigLoader.load_config(config_path, tsv_config_path)
    
    # Load ROM model
    rom_model = ROMInterpolator.load_rom_model(rom_model_path)
    
    # Load POD model
    pod_model = load_pod_model(pod_model_path)
    
    basis = pod_model.basis
    mean_field = pod_model.mean_field
    
    return run_optimization(model_config, rom_model, basis, mean_field; save_history=save_history, history_file=history_file)
end

end # module
