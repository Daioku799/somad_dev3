module Validator

using ..Types

export validate_and_create_polygon

"""
    compute_bbox(vertices::Vector{Tuple{Float64, Float64}})

Compute the axis-aligned bounding box for a set of vertices.
"""
function compute_bbox(vertices)
    xmin = minimum(p -> p[1], vertices)
    xmax = maximum(p -> p[1], vertices)
    ymin = minimum(p -> p[2], vertices)
    ymax = maximum(p -> p[2], vertices)
    return xmin, ymin, xmax, ymax
end

"""
    validate_and_create_polygon(raw_vertices::Vector{Tuple{Float64, Float64}}; tol=1e-12)

Normalize polygon vertices: remove duplicates, ensure closure, and compute BBox.
"""
function validate_and_create_polygon(raw_vertices; tol=1e-12)
    if length(raw_vertices) < 3
        return nothing # Degenerate
    end

    # 1. Remove consecutive duplicates
    v_clean = Tuple{Float64, Float64}[]
    for v in raw_vertices
        if isempty(v_clean) || hypot(v[1] - v_clean[end][1], v[2] - v_clean[end][2]) > tol
            push!(v_clean, v)
        end
    end

    # 2. Ensure closure (first == last)
    if hypot(v_clean[1][1] - v_clean[end][1], v_clean[1][2] - v_clean[end][2]) > tol
        push!(v_clean, v_clean[1])
    end

    if length(v_clean) < 4 # A closed triangle must have 4 points (v1, v2, v3, v1)
        return nothing
    end

    # 3. Compute BBox
    xmin, ymin, xmax, ymax = compute_bbox(v_clean)
    
    return GdsPolygon(v_clean, BBox(xmin, ymin, xmax, ymax))
end

end # module
