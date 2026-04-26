module GdsIntegration

# Access GdsMapping which is in src/GdsMapping/GdsMapping.jl
include("../GdsMapping/GdsMapping.jl")
using .GdsMapping

export is_included_chip

"""
    is_included_chip(a1, a2, layer::Any, zmin::Float64, zmax::Float64; samples=3)

Check if cell (a1, a2) is included in the silicon chip defined by GdsLayer.
Uses sub-cell sampling (samples x samples in XY) for smoother boundaries.
"""
function is_included_chip(a1, a2, layer::Any, zmin::Float64, zmax::Float64; samples=3)
    # 1. Z-axis overlap check
    czlo, czhi = min(a1[3], a2[3]), max(a1[3], a2[3])
    if czhi <= zmin || czlo >= zmax
        return false
    end

    # 2. XY sub-sampling check in GDS layer
    xlo, xhi = min(a1[1], a2[1]), max(a1[1], a2[1])
    ylo, yhi = min(a1[2], a2[2]), max(a1[2], a2[2])
    
    inside_count = 0
    total_count = samples * samples
    
    for i in 1:samples, j in 1:samples
        x = xlo + (i - 0.5) * (xhi - xlo) / samples
        y = ylo + (j - 0.5) * (yhi - ylo) / samples
        if is_point_in_layer(x, y, layer)
            inside_count += 1
        end
    end
    
    return (inside_count / total_count) >= 0.5
end

end # module
