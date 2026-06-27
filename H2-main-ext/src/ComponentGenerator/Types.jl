module Types

export GeometryObject, ShapeType, CYLINDER, SPHERE, BOX
export Point2D, DensityCell
export ValidationErrorType, NO_ERROR, BOUNDARY_VIOLATION, PITCH_VIOLATION
export ValidationResult
export get_cylinder_params, get_sphere_params, get_box_params

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

struct Point2D
    x::Float64
    y::Float64
end

struct DensityCell
    x_bounds::Tuple{Float64, Float64}
    y_bounds::Tuple{Float64, Float64}
    center::Tuple{Float64, Float64}

    function DensityCell(x_bounds::Tuple{Float64, Float64}, y_bounds::Tuple{Float64, Float64})
        cx = (x_bounds[1] + x_bounds[2]) / 2.0
        cy = (y_bounds[1] + y_bounds[2]) / 2.0
        new(x_bounds, y_bounds, (cx, cy))
    end
    function DensityCell(x_bounds::Tuple{Float64, Float64}, y_bounds::Tuple{Float64, Float64}, center::Tuple{Float64, Float64})
        new(x_bounds, y_bounds, center)
    end
end

@enum ValidationErrorType begin
    NO_ERROR
    BOUNDARY_VIOLATION
    PITCH_VIOLATION
end

struct ValidationResult
    is_valid::Bool
    error_type::ValidationErrorType
    message::String
end

function get_cylinder_params(obj::GeometryObject)
    @assert obj.type == CYLINDER "GeometryObject is not a CYLINDER"
    x, y, z = obj.pos
    r, h = obj.dims
    return (x, y), r, z - h/2.0, z + h/2.0
end

function get_sphere_params(obj::GeometryObject)
    @assert obj.type == SPHERE "GeometryObject is not a SPHERE"
    return obj.pos, obj.dims[1]
end

function get_box_params(obj::GeometryObject)
    @assert obj.type == BOX "GeometryObject is not a BOX"
    x, y, z = obj.pos
    lx, ly, lz = obj.dims
    a1 = (x - lx/2.0, y - ly/2.0, z - lz/2.0)
    a2 = (x + lx/2.0, y + ly/2.0, z + lz/2.0)
    return a1, a2
end

end # module
