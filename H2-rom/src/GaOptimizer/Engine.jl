# Engine.jl - Core optimization loop and genetic operators

using .ConstraintManager: adjust_constraints!
using ..ROMInterpolator: evaluate_rom, get_tmax

"""
    crossover(parent1::Individual, parent2::Individual, config::OptimizationConfig, model_config; alpha=0.5)

BLX-alpha (Blend Crossover) operator.
Generates two offspring from two parents and applies ConstraintManager.adjust_constraints!.
"""
function crossover(parent1::Individual, parent2::Individual, config::OptimizationConfig, model_config; alpha=0.5)::Tuple{Individual, Individual}
    n = length(parent1.mu)
    child1_mu = Vector{Float64}(undef, n)
    child2_mu = Vector{Float64}(undef, n)
    
    for i in 1:n
        v1 = parent1.mu[i]
        v2 = parent2.mu[i]
        d_min = min(v1, v2)
        d_max = max(v1, v2)
        diff = d_max - d_min
        
        # BLX-alpha sampling
        lower = d_min - alpha * diff
        upper = d_max + alpha * diff
        
        child1_mu[i] = lower + rand() * (upper - lower)
        child2_mu[i] = lower + rand() * (upper - lower)
    end
    
    # Automatically adjust constraints in-place to ensure physical validity
    adjust_constraints!(child1_mu, model_config)
    adjust_constraints!(child2_mu, model_config)
    
    return (Individual(child1_mu), Individual(child2_mu))
end

"""
    mutate!(ind::Individual, config::OptimizationConfig, model_config; sigma=0.1)

Gaussian mutation operator applied to an individual in-place and applies ConstraintManager.adjust_constraints!.
"""
function mutate!(ind::Individual, config::OptimizationConfig, model_config; sigma=0.1)::Individual
    n = length(ind.mu)
    
    rho_cell_max = 1.0
    if model_config.tsv.mode == :density && model_config.tsv.density !== nothing
        rho_cell_max = model_config.tsv.density.rho_cell_max
    end
    
    for i in 1:n
        if rand() < config.mut_rate
            # Add Gaussian noise scaled by sigma and max density
            ind.mu[i] += randn() * sigma * rho_cell_max
        end
    end
    
    # Automatically adjust constraints in-place to ensure physical validity
    adjust_constraints!(ind.mu, model_config)
    
    # Reset evaluation status
    ind.fitness = Inf
    ind.is_fvm_verified = false
    ind.extrapolation_score = 0.0
    
    return ind
end

"""
    evaluate_population!(population::Vector{Individual}, model, basis, mean_field)

Evaluate the fitness of each individual in the population using the ROM model.
Computes the maximum temperature and sets it as the fitness.
"""
function evaluate_population!(population::Vector{Individual}, model, basis, mean_field)
    for ind in population
        # Evaluate ROM
        theta = evaluate_rom(model, basis, mean_field, ind.mu)
        # Get maximum temperature
        tmax = get_tmax(theta)
        # Set fitness
        ind.fitness = tmax
    end
    return population
end

"""
    tournament_select(population::Vector{Individual}, tournament_size::Int=3)::Individual

Select one individual from the population using tournament selection.
Assumes population is already sorted or we select a random subset and pick the best (minimum fitness).
"""
function tournament_select(population::Vector{Individual}, tournament_size::Int=3)::Individual
    n = length(population)
    t_size = min(tournament_size, n)
    indices = Int[]
    sizehint!(indices, t_size)
    while length(indices) < t_size
        idx = rand(1:n)
        if !(idx in indices)
            push!(indices, idx)
        end
    end
    best_candidate = population[indices[1]]
    for i in 2:t_size
        candidate = population[indices[i]]
        if candidate.fitness < best_candidate.fitness
            best_candidate = candidate
        end
    end
    return best_candidate
end

"""
    select_next_generation(state::OptimizationState, config::OptimizationConfig, model_config)::Vector{Individual}

Select the next generation using elite preservation and tournament selection.
"""
function select_next_generation(state::OptimizationState, config::OptimizationConfig, model_config)::Vector{Individual}
    next_pop = Vector{Individual}(undef, config.n_pop)
    
    # Sort current population by fitness (lower is better, since we minimize Tmax)
    sorted_pop = sort(state.population, by = ind -> ind.fitness)
    
    # 1. Elite preservation
    for i in 1:config.n_elite
        if i <= length(sorted_pop)
            next_pop[i] = Individual(
                copy(sorted_pop[i].mu),
                sorted_pop[i].fitness,
                sorted_pop[i].is_fvm_verified,
                sorted_pop[i].extrapolation_score
            )
        end
    end
    
    # 2. Recombination and Mutation to fill the rest of the population
    idx = config.n_elite + 1
    while idx <= config.n_pop
        parent1 = tournament_select(sorted_pop)
        parent2 = tournament_select(sorted_pop)
        
        child1_ind, child2_ind = if rand() < config.cx_rate
            crossover(parent1, parent2, config, model_config)
        else
            (Individual(copy(parent1.mu)), Individual(copy(parent2.mu)))
        end
        
        mutate!(child1_ind, config, model_config)
        mutate!(child2_ind, config, model_config)
        
        next_pop[idx] = child1_ind
        idx += 1
        if idx <= config.n_pop
            next_pop[idx] = child2_ind
            idx += 1
        end
    end
    
    return next_pop
end

