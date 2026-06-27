module ComponentGenerator

include("Types.jl")
include("Layout.jl")
include("Validator.jl")
include("Main.jl")

using .Types
using .Layout
using .Validator
using .Main

# Re-export
export GeometryObject, ShapeType, CYLINDER, SPHERE, BOX
export generate_components
export generate_all_components

using ..ConfigLoader: ModelConfig, calculate_zm

"""
    generate_all_components(config::ModelConfig) -> Vector{GeometryObject}

Unified component generation API:
1. Call `Layout.expand_coordinates` to get the common (x, y) list.
2. Call `Validator.validate_physical_constraints` to check boundary & pitch constraints.
3. Construct Cylinder (TSV) and Sphere (Bump) objects based on Z-coordinates.
"""
function generate_all_components(config::ModelConfig)
    # 1. Coordinate expansion
    pts = Layout.expand_coordinates(config.tsv, config.lx, config.ly)
    
    # 2. Validation
    validation = Validator.validate_physical_constraints(pts, config)
    if !validation.is_valid
        error("Physical constraints validation failed: $(validation.message)")
    end
    
    # 3. Z-coordinate calculations
    zm = calculate_zm(config)
    
    objects = GeometryObject[]
    copper_id = 1
    solder_id = 3

    # TSV (Cylinders)
    silicon_starts = [zm[3], zm[6], zm[9]]
    for zs in silicon_starts
        for pt in pts
            push!(objects, GeometryObject(CYLINDER, (pt.x, pt.y, zs), (config.tsv.radius, config.tsv.height), copper_id))
        end
    end

    # Solder Bumps (Spheres)
    dp = config.d_ufill * 0.5
    underfill_starts = [zm[2], zm[5], zm[8], zm[11]]
    for us in underfill_starts
        for pt in pts
            push!(objects, GeometryObject(SPHERE, (pt.x, pt.y, us + dp), (config.r_bump,), solder_id))
        end
    end

    return objects
end

end # module
