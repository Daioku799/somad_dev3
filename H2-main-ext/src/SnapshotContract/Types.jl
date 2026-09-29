struct SnapshotIdentity
    case_id::String
    layout_signature::String
    grid_signature::String
    physics_contract_hash::String
    temperature_field_signature::String
    material_field_signature::String
    conductivity_field_signature::String
end

function Base.:(==)(left::SnapshotIdentity, right::SnapshotIdentity)
    return all(
        getfield(left, name) == getfield(right, name)
        for name in fieldnames(SnapshotIdentity)
    )
end

struct ThermalSnapshot
    envelope::ArtifactEnvelope
    counts::NTuple{16,Int}
    temperature::Array{Float64,3}
    material_id::Array{UInt8,3}
    conductivity::Array{Float64,3}
    geometry::GridGeometry3D
    identity::SnapshotIdentity
    physics::PhysicsContract
    quality::SolveQuality
    policy::NumericalPolicy
    approval_record::ApprovalRecord
    temperature_unit::Symbol
end
