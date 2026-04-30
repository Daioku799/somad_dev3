module ValidationPlot

include("Palettes.jl")
include("Slicer.jl")
include("Snapshot.jl")
include("Main.jl")

using .Palettes
using .Slicer
using .Snapshot
using .Main

# Re-export
export plot_model_validation, LEGACY_COLOR_PALETTE, MATERIAL_LABELS
export get_indices, get_xy_slice, get_yz_slice, get_xz_slice
export load_snapshot

end # module
