module Types

export GeometryObject, ShapeType, CYLINDER, SPHERE, BOX

@enum ShapeType begin
    CYLINDER
    SPHERE
    BOX
end

struct GeometryObject
    type::ShapeType
    pos::Tuple{Float64, Float64, Float64} # (x, y, z)
    dims::Tuple{Vararg{Float64}}           # (radius, height) or (radius,) or (lx, ly, lz)
    mat_id::Int
end

end # module
