function _require_nonempty(label::AbstractString, value::AbstractString)
    isempty(strip(value)) && throw(ContractError("$label must not be empty"))
end

function _require_sha256(label::AbstractString, value::AbstractString)
    occursin(r"^[0-9a-f]{64}$", value) ||
        throw(ContractError("$label must be a lowercase SHA-256 hex digest"))
end

function validate_physics_contract(contract::PhysicsContract)::PhysicsContract
    _require_nonempty("physics_config_id", contract.physics_config_id)
    _require_nonempty("physics_config_hash", contract.physics_config_hash)
    _require_nonempty("material_table_hash", contract.material_table_hash)
    _require_nonempty("heat_map_hash", contract.heat_map_hash)
    _require_nonempty("layout_rule_version", contract.layout_rule_version)
    _require_sha256("physics_config_hash", contract.physics_config_hash)
    _require_sha256("material_table_hash", contract.material_table_hash)
    _require_sha256("heat_map_hash", contract.heat_map_hash)

    metadata = contract.metadata
    for (label, value) in (
        ("boundary_condition_id", metadata.boundary_condition_id),
        ("heat_condition_id", metadata.heat_condition_id),
        ("material_table_id", metadata.material_table_id),
        ("geometry_id", metadata.geometry_id),
        ("metadata.layout_rule_version", metadata.layout_rule_version),
    )
        _require_nonempty(label, value)
    end
    isfinite(metadata.total_power_W) && metadata.total_power_W >= 0.0 ||
        throw(ContractError("total_power_W must be finite and non-negative"))
    all(>(0), metadata.grid_shape) || throw(ContractError("grid dimensions must be positive"))

    for (label, value) in (
        ("tsv_diameter_m", contract.tsv_diameter_m),
        ("min_pitch_m", contract.min_pitch_m),
        ("metadata.tsv_diameter_m", metadata.tsv_diameter_m),
        ("metadata.min_pitch_m", metadata.min_pitch_m),
    )
        isfinite(value) && value > 0.0 || throw(ContractError("$label must be finite and positive"))
    end
    contract.tsv_diameter_m == metadata.tsv_diameter_m ||
        throw(ContractError("TSV diameter differs between physics contract and metadata"))
    contract.min_pitch_m == metadata.min_pitch_m ||
        throw(ContractError("minimum pitch differs between physics contract and metadata"))
    contract.layout_rule_version == metadata.layout_rule_version ||
        throw(ContractError("layout rule version differs between physics contract and metadata"))
    contract.physics_config_hash == content_hash(metadata) ||
        throw(ContractError("physics_config_hash does not match metadata content"))

    ids = contract.silicon_material_ids
    ids[1] != ids[2] || throw(ContractError("silicon material IDs must be distinct"))
    all(k -> isfinite(k) && k > 0.0, contract.expected_silicon_conductivity_W_mK) ||
        throw(ContractError("expected silicon conductivities must be finite and positive"))
    contract.units == UnitContract() || throw(ContractError("unsupported or ambiguous unit contract"))
    return contract
end

function validate_baseline_physics(contract::PhysicsContract)::PhysicsContract
    validate_physics_contract(contract)
    contract.tsv_diameter_m == 40e-6 ||
        throw(ContractError("baseline TSV diameter must be 40 um"))
    contract.min_pitch_m == 80e-6 ||
        throw(ContractError("baseline minimum pitch must be 80 um"))
    contract.metadata.grid_shape == (240, 240, 30) ||
        throw(ContractError("baseline grid must be 240x240x30"))
    return contract
end

function approve_policy(policy::NumericalPolicy, record::ApprovalRecord)::NumericalPolicy
    record.approved || throw(ContractError("approval record is not approved"))
    record.record_id == policy.approval_record_id ||
        throw(ContractError("approval record ID does not match numerical policy"))
    record.subject_id == policy.policy_id ||
        throw(ContractError("approval subject does not match numerical policy"))
    record.subject_hash == policy_content_hash(policy) ||
        throw(ContractError("approval subject hash does not match numerical policy content"))
    return NumericalPolicy(
        policy.policy_id,
        policy.approval_record_id,
        policy.conductance_rtol,
        policy.gradient_rtol,
        policy.solver_relative_residual_max,
        policy.energy_relative_imbalance_max,
        true,
    )
end

function validate_numerical_policy(policy::NumericalPolicy,
                                   record::ApprovalRecord)::NumericalPolicy
    policy.approved || throw(ContractError("numerical policy was not derived from approval"))
    approve_policy(policy, record)
    return policy
end

function validate_artifact_envelope(envelope::ArtifactEnvelope;
                                    expected_kind::Union{Nothing,AbstractString}=nothing)::ArtifactEnvelope
    envelope.schema_version == CURRENT_SCHEMA_VERSION ||
        throw(ContractError("unsupported artifact schema version: $(envelope.schema_version)"))
    envelope.quality == VERIFIED ||
        throw(ContractError("artifact quality is not VERIFIED: $(envelope.quality)"))
    _require_nonempty("artifact_kind", envelope.artifact_kind)
    _require_nonempty("artifact_id", envelope.artifact_id)
    _require_nonempty("run_id", envelope.run_id)
    occursin(r"^[^:]+:sha256:[0-9a-f]{64}$", envelope.artifact_id) ||
        throw(ContractError("current artifact_id must be a content-derived SHA-256 ID"))
    if expected_kind !== nothing && envelope.artifact_kind != expected_kind
        throw(ContractError("artifact kind mismatch: expected $expected_kind, got $(envelope.artifact_kind)"))
    end
    return envelope
end

function promote_artifact(envelope::ArtifactEnvelope,
                          target::QualityState)::ArtifactEnvelope
    envelope.quality == LEGACY_UNVERIFIED &&
        throw(ContractError("LEGACY_UNVERIFIED artifacts cannot be promoted"))
    envelope.schema_version == CURRENT_SCHEMA_VERSION ||
        throw(ContractError("only current-schema artifacts can be promoted"))
    envelope.quality == UNVERIFIED ||
        throw(ContractError("only UNVERIFIED artifacts can be promoted"))
    target == VERIFIED || throw(ContractError("the only supported promotion target is VERIFIED"))
    return ArtifactEnvelope(
        envelope.schema_version,
        envelope.artifact_kind,
        envelope.artifact_id,
        VERIFIED,
        envelope.run_id,
    )
end
