using Test

if !isdefined(Main, :GaOptimizer)
    include("../src/GaOptimizer/GaOptimizer.jl")
end
using .GaOptimizer: Individual, OptimizationState, OptimizationConfig

# Define H2MainExt wrapper to access GASettings for mapping test
module H2MainExtTest
    const SRC_DIR = abspath(joinpath(@__DIR__, "../../H2-main-ext/src"))
    include(joinpath(SRC_DIR, "ConfigLoader/ConfigLoader.jl"))
    using .ConfigLoader
end
using .H2MainExtTest.ConfigLoader: GASettings

@testset "GaOptimizer Types Test" begin
    # 1. Test Individual construction and field types
    mu = [0.1, 0.5, 0.9, 0.0]
    ind = Individual(mu)
    
    @test ind.mu == mu
    @test ind.fitness === Inf
    @test ind.is_fvm_verified === false
    @test ind.extrapolation_score === 0.0
    
    # Custom values
    ind2 = Individual(mu, 350.5, true, 1.2)
    @test ind2.mu == mu
    @test ind2.fitness == 350.5
    @test ind2.is_fvm_verified === true
    @test ind2.extrapolation_score == 1.2
    
    # Check type safety
    @test typeof(ind.mu) == Vector{Float64}
    @test typeof(ind.fitness) == Float64
    @test typeof(ind.is_fvm_verified) == Bool
    @test typeof(ind.extrapolation_score) == Float64

    # 2. Test OptimizationState construction
    pop = [ind, ind2]
    state = OptimizationState(pop)
    
    @test state.generation == 0
    @test state.best_individual === nothing
    @test state.population === pop
    @test state.history == Float64[]
    
    # Check updating fields
    state.generation = 1
    state.best_individual = ind2
    push!(state.history, 350.5)
    
    @test state.generation == 1
    @test state.best_individual === ind2
    @test state.history == [350.5]
    
    @test typeof(state.generation) == Int
    @test typeof(state.best_individual) == Individual
    @test typeof(state.population) == Vector{Individual}
    @test typeof(state.history) == Vector{Float64}

    # 3. Test OptimizationConfig construction and mapping
    ga_settings = GASettings(100, 200, 0.75, 0.05, 4)
    opt_config = OptimizationConfig(ga_settings)
    
    @test opt_config.n_pop == 100
    @test opt_config.n_gen == 200
    @test opt_config.cx_rate == 0.75
    @test opt_config.mut_rate == 0.05
    @test opt_config.n_elite == 4
    
    @test typeof(opt_config.n_pop) == Int
    @test typeof(opt_config.n_gen) == Int
    @test typeof(opt_config.cx_rate) == Float64
    @test typeof(opt_config.mut_rate) == Float64
    @test typeof(opt_config.n_elite) == Int
end

