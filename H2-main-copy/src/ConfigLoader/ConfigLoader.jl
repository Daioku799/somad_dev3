module ConfigLoader

include("Types.jl")
include("Defaults.jl")
include("Calculators.jl")
include("Main.jl")

using .Types
using .Defaults
using .Calculators
using .Main

# Re-export key components
export Material, Layer, TSVConfig, ModelConfig
export generate_test_config, calculate_zm, load_config, calculate_solder_radius

end # module
