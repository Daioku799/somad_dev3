module ValidationPlot

include("Palettes.jl")
include("Main.jl")
using .Main
using .Palettes

# Re-export
export plot_model_validation, LEGACY_COLOR_PALETTE, MATERIAL_LABELS

end # module
