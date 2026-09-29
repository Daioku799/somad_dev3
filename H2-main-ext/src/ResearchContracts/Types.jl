struct ContractError <: Exception
    message::String
end

Base.showerror(io::IO, error::ContractError) = print(io, "ContractError: ", error.message)

struct UnitContract
    temperature::Symbol
    gradient::Symbol
    length::Symbol
    conductivity::Symbol
    heat_rate::Symbol
    heat_flux::Symbol
end

UnitContract() = UnitContract(:K, :K_per_m, :m, :W_per_mK, :W, :W_per_m2)

struct PhysicsMetadata
    boundary_condition_id::String
    heat_condition_id::String
    material_table_id::String
    geometry_id::String
    total_power_W::Float64
    tsv_diameter_m::Float64
    min_pitch_m::Float64
    grid_shape::NTuple{3,Int}
    layout_rule_version::String
end

struct PhysicsContract
    physics_config_id::String
    physics_config_hash::String
    material_table_hash::String
    heat_map_hash::String
    layout_rule_version::String
    tsv_diameter_m::Float64
    min_pitch_m::Float64
    silicon_material_ids::NTuple{2,UInt8}
    expected_silicon_conductivity_W_mK::NTuple{2,Float64}
    metadata::PhysicsMetadata
    units::UnitContract
end

struct NumericalPolicy
    policy_id::String
    approval_record_id::String
    conductance_rtol::Float64
    gradient_rtol::Float64
    solver_relative_residual_max::Float64
    energy_relative_imbalance_max::Float64
    approved::Bool

    function NumericalPolicy(policy_id::String,
                             approval_record_id::String,
                             conductance_rtol::Real,
                             gradient_rtol::Real,
                             solver_relative_residual_max::Real,
                             energy_relative_imbalance_max::Real,
                             approved::Bool)
        values = Float64.(
            (conductance_rtol, gradient_rtol, solver_relative_residual_max,
             energy_relative_imbalance_max),
        )
        all(isfinite, values) || throw(ContractError("numerical policy contains non-finite values"))
        all(>(0.0), values) || throw(ContractError("numerical policy tolerances must be positive"))
        isempty(policy_id) && throw(ContractError("policy_id must not be empty"))
        isempty(approval_record_id) && throw(ContractError("approval_record_id must not be empty"))
        new(policy_id, approval_record_id, values..., approved)
    end
end

struct ApprovalRecord
    record_id::String
    subject_id::String
    subject_hash::String
    approved::Bool
end

@enum QualityState begin
    UNVERIFIED
    VERIFIED
    LEGACY_UNVERIFIED
end

const CURRENT_SCHEMA_VERSION = v"1.0.0"

struct ArtifactEnvelope
    schema_version::VersionNumber
    artifact_kind::String
    artifact_id::String
    quality::QualityState
    run_id::String
end
