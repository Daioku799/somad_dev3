struct FieldIdentity
    case_id::String
    layout_signature::String
    grid_signature::String
    physics_contract_hash::String
    temperature_field_signature::String
    material_field_signature::String
    conductivity_field_signature::String
    objective_definition_id::String
end
struct FieldBundle
    counts::NTuple{16,Int}
    temperature::Array{Float64,3}
    material_id::Array{UInt8,3}
    conductivity::Array{Float64,3}
    geometry::GridGeometry3D
    identity::FieldIdentity
    physics::PhysicsContract
    temperature_unit::Symbol
end

struct TmaxResult
    value_K::Float64
    index::CartesianIndex{3}
    coordinate_m::NTuple{3,Float64}
    unit::Symbol
end

struct GmaxResult
    value_K_per_m::Float64
    index::CartesianIndex{3}
    coordinate_m::NTuple{3,Float64}
    material_id::UInt8
    components_K_per_m::NTuple{3,Float64}
    unit::Symbol
end

struct ObjectiveEvaluation
    tmax::Float64
    gmax::Float64
    total_count::Int
    tmax_index::CartesianIndex{3}
    tmax_coordinate_m::NTuple{3,Float64}
    gmax_index::CartesianIndex{3}
    gmax_coordinate_m::NTuple{3,Float64}
    gmax_material_id::UInt8
    gmax_components::NTuple{3,Float64}
    identity::FieldIdentity
    temperature_unit::Symbol
    gradient_unit::Symbol
end
