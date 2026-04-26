module GdsMapping

include("Types.jl")
include("Validator.jl")
include("Main.jl")
include("Query.jl")

using .Types
using .Validator
using .Main
using .Query

# Re-export
export GdsPolygon, GdsLayer, BBox
export load_gds_layer, is_point_in_layer, get_plot_data

end # module
