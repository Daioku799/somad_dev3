module GeometryLogic

include("../GdsMapping/GdsMapping.jl")
include("Primitives.jl")
include("GdsIntegration.jl")

using .GdsMapping
using .Primitives
using .GdsIntegration

# Re-export all necessary types and functions
export is_included_rect, is_included_cyl, is_included_sph
export is_included_chip
export GdsPolygon, GdsLayer, BBox
export load_gds_layer, get_plot_data

end # module
