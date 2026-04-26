module Types

export GdsPolygon, GdsLayer, BBox

struct BBox
    xmin::Float64
    ymin::Float64
    xmax::Float64
    ymax::Float64
end

struct GdsPolygon
    vertices::Vector{Tuple{Float64, Float64}}
    bbox::BBox
end

struct GdsLayer
    layer_id::Int
    polygons::Vector{GdsPolygon}
end

end # module
