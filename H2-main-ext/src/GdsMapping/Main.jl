module Main

using ..Types
using ..Validator

# Access SimpleGDS which is copied to src/SimpleGDS.jl
if !isdefined(Main, :SimpleGDS)
    include("../SimpleGDS.jl")
end
using .SimpleGDS

export load_gds_layer

"""
    load_gds_layer(filename::String, layer_id::Int; unit_scale=1e-6)

Load polygons from a GDSII file for a specific layer and convert units to meters.
"""
function load_gds_layer(filename::String, layer_id::Int; unit_scale=1e-6)
    if !isfile(filename)
        throw(ArgumentError("GDS file not found: $filename"))
    end

    gds_lib = SimpleGDS.load(filename)
    polygons = GdsPolygon[]

    for structure in gds_lib.structures
        for element in structure.elements
            if element isa SimpleGDS.Boundary && element.layer == layer_id
                # Convert SimpleGDS.Point to Tuple{Float64, Float64} and apply unit scale
                raw_vertices = [(p.x * unit_scale, p.y * unit_scale) for p in element.xy]
                
                poly = validate_and_create_polygon(raw_vertices)
                if poly !== nothing
                    push!(polygons, poly)
                end
            end
        end
    end

    return GdsLayer(layer_id, polygons)
end

end # module
