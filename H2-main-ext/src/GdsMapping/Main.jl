module Main

using ..Types
using ..Validator
using JSON

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

    # Check boundaries against config.json if it exists
    if isfile("config.json")
        try
            cfg = JSON.parsefile("config.json")
            lx = get(cfg, "lx", 1.2e-3)
            ly = get(cfg, "ly", 1.2e-3)
            for poly in polygons
                if poly.bbox.xmin < 0.0 || poly.bbox.xmax > lx || poly.bbox.ymin < 0.0 || poly.bbox.ymax > ly
                    @warn "Polygon boundary exceeds chip range: BBox=($(poly.bbox.xmin), $(poly.bbox.ymin)) - ($(poly.bbox.xmax), $(poly.bbox.ymax)), Chip range=(0.0, 0.0) - ($lx, $ly)"
                end
            end
        catch e
            @warn "Failed to parse config.json for boundary check: $e"
        end
    end

    return GdsLayer(layer_id, polygons)
end

end # module
