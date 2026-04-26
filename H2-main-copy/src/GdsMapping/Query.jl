module Query

using PolygonOps
using ..Types

export is_point_in_layer, get_plot_data

"""
    is_point_in_polygon(x::Float64, y::Float64, poly::GdsPolygon)

Check if a point (x, y) is inside a specific polygon using BBox check and inpolygon.
"""
function is_point_in_polygon(x, y, poly)
    # 1. BBox Check (Early Exit)
    if x < poly.bbox.xmin || x > poly.bbox.xmax || y < poly.bbox.ymin || y > poly.bbox.ymax
        return false
    end

    # 2. PolygonOps.inpolygon
    # Returns 1 for inside, 0 for outside, 0.5 for boundary
    val = inpolygon((x, y), poly.vertices)
    return val >= 0.5
end

"""
    is_point_in_layer(x::Float64, y::Float64, layer::GdsLayer)

Check if a point (x, y) is inside any polygon of the layer.
"""
function is_point_in_layer(x, y, layer)
    for poly in layer.polygons
        if is_point_in_polygon(x, y, poly)
            return true
        end
    end
    return false
end

"""
    get_plot_data(layer::GdsLayer)

Return a vector of matrices, each matrix being (N x 2) vertices of a polygon.
Useful for plotting boundaries.
"""
function get_plot_data(layer::GdsLayer)
    return [reduce(hcat, [[p[1], p[2]] for p in poly.vertices])' for poly in layer.polygons]
end

end # module
