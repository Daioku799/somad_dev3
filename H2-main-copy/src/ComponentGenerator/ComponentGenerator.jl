module ComponentGenerator

include("Types.jl")
include("Main.jl")

using .Types
using .Main

# Re-export
export GeometryObject, ShapeType, CYLINDER, SPHERE, BOX
export generate_components

end # module
