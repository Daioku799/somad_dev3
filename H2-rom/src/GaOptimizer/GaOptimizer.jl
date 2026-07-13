module GaOptimizer

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

include("Types.jl")
include("ConstraintManager.jl")
include("ReliabilityManager.jl")
include("Engine.jl")

export Individual, OptimizationState, OptimizationConfig, ConstraintManager, ReliabilityManager
export crossover, mutate!, evaluate_population!, tournament_select, select_next_generation

end # module
