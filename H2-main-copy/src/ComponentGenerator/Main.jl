module Main

using ..Types: GeometryObject, ShapeType, CYLINDER, SPHERE, BOX
# Access ConfigLoader
include("../ConfigLoader/ConfigLoader.jl")
using .ConfigLoader

export generate_components

"""
    generate_components(config::Any, zm::Vector{Float64})

Generate a list of GeometryObject (TSVs and Bumps) based on config and calculated markers.
"""
function generate_components(config::Any, zm::Vector{Float64})
    objects = GeometryObject[]
    
    # Coordinates from config (already extracted in ConfigLoader.generate_test_config or load_config)
    coords = config.tsv.coords
    
    # Material IDs based on Defaults.jl
    # MAT_COPPER = 1, MAT_SOLDER = 3
    copper_id = 1
    solder_id = 3

    # 1. Generate TSVs (Cylinders)
    # Original model has TSVs in 3 Silicon layers:
    # Silicon 1: zm2 to zm4 (height = h_tsv = 0.1mm)
    # Silicon 2: zm5 to zm7
    # Silicon 3: zm8 to zm10
    silicon_starts = [zm[3], zm[6], zm[9]]
    for zs in silicon_starts
        for (x, y) in coords
            # Cylinder dims: (radius, height)
            # Center pos: (x, y, zs) 
            push!(objects, GeometryObject(CYLINDER, (x, y, zs), (config.tsv.radius, config.tsv.height), copper_id))
        end
    end

    # 2. Generate Solder Bumps (Spheres)
    # Original model has Bumps in 4 Underfill layers at specific heights:
    # Underfill 1: zm1 + dp (dp = d_ufill * 0.5)
    # Underfill 2: zm4 + dp
    # Underfill 3: zm7 + dp
    # Underfill 4: zm10 + dp
    dp = config.d_ufill * 0.5
    underfill_starts = [zm[2], zm[5], zm[8], zm[11]]
    for us in underfill_starts
        for (x, y) in coords
            # Sphere dims: (radius,)
            # Center pos: (x, y, us + dp)
            push!(objects, GeometryObject(SPHERE, (x, y, us + dp), (config.r_bump,), solder_id))
        end
    end

    return objects
end

end # module
