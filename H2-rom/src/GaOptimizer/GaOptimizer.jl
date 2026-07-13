module GaOptimizer

try
    using ROMInterpolator
catch
    if !isdefined(Main, :ROMInterpolator)
        path = joinpath(@__DIR__, "..", "ROMInterpolator", "ROMInterpolator.jl")
        Main.eval(:(include($path)))
    end
    using Main.ROMInterpolator
end

include("Types.jl")
include("ConstraintManager.jl")
include("Engine.jl")

export Individual, OptimizationState, OptimizationConfig, ConstraintManager
export crossover, mutate!, evaluate_population!, tournament_select, select_next_generation

end # module
