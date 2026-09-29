function _snapshot_grid_signature(geometry::GridGeometry3D)::String
    return content_id("grid", (
        x_faces=geometry.x_faces,
        y_faces=geometry.y_faces,
        z_faces=geometry.z_faces,
        physical_ranges=geometry.physical_ranges,
    ))
end

function _snapshot_layout_signature(counts::NTuple{16,Int},
                                    physics::PhysicsContract)::String
    return content_id("layout", (
        counts=counts,
        tsv_diameter_m=physics.tsv_diameter_m,
        min_pitch_m=physics.min_pitch_m,
        rule_version=physics.layout_rule_version,
    ))
end

function _snapshot_artifact_id(counts, identity, physics, quality, policy,
                               approval_record, temperature_unit)::String
    return content_id("snapshot", (
        counts=counts,
        identity=identity,
        physics_contract_hash=content_hash(physics),
        quality=(
            status=Int(quality.status),
            converged=quality.converged,
            final_relative_residual=quality.final_relative_residual,
            energy_relative_imbalance=quality.energy_relative_imbalance,
            policy_id=quality.policy_id,
            reasons=quality.reasons,
        ),
        policy_hash=policy_content_hash(policy),
        approval_record_id=approval_record.record_id,
        temperature_unit=temperature_unit,
    ))
end

function _validate_quality(snapshot::ThermalSnapshot)
    validate_numerical_policy(snapshot.policy, snapshot.approval_record)
    quality = snapshot.quality
    quality.policy_id == snapshot.policy.policy_id ||
        throw(ContractError("snapshot quality policy ID mismatch"))
    quality.status == PASS || throw(ContractError("snapshot solver quality is not PASS"))
    quality.converged || throw(ContractError("snapshot solver did not converge"))
    isempty(quality.reasons) || throw(ContractError("PASS snapshot quality contains failure reasons"))
    isfinite(quality.final_relative_residual) && quality.final_relative_residual >= 0.0 ||
        throw(ContractError("snapshot residual is invalid"))
    quality.final_relative_residual <= snapshot.policy.solver_relative_residual_max ||
        throw(ContractError("snapshot residual exceeds approved policy"))
    isfinite(quality.energy_relative_imbalance) && quality.energy_relative_imbalance >= 0.0 ||
        throw(ContractError("snapshot energy imbalance is invalid"))
    quality.energy_relative_imbalance <= snapshot.policy.energy_relative_imbalance_max ||
        throw(ContractError("snapshot energy imbalance exceeds approved policy"))
end

function validate_snapshot(snapshot::ThermalSnapshot)::ThermalSnapshot
    validate_artifact_envelope(snapshot.envelope; expected_kind="snapshot")
    validate_physics_contract(snapshot.physics)
    _validate_quality(snapshot)
    snapshot.temperature_unit == :K || throw(ContractError("snapshot temperature unit must be K"))
    all(count -> 0 <= count <= 9, snapshot.counts) ||
        throw(ContractError("snapshot TSV counts must be in 0:9"))

    geometry = snapshot.geometry
    expected_shape = (
        length(geometry.x_faces) - 1,
        length(geometry.y_faces) - 1,
        length(geometry.z_faces) - 1,
    )
    size(snapshot.temperature) == expected_shape ||
        throw(ContractError("snapshot temperature shape does not match geometry"))
    size(snapshot.material_id) == expected_shape ||
        throw(ContractError("snapshot material shape does not match geometry"))
    size(snapshot.conductivity) == expected_shape ||
        throw(ContractError("snapshot conductivity shape does not match geometry"))
    all(isfinite, snapshot.temperature) ||
        throw(ContractError("snapshot temperature contains non-finite values"))
    all(value -> isfinite(value) && value > 0.0, snapshot.conductivity) ||
        throw(ContractError("snapshot conductivity must be finite and positive"))

    identity = snapshot.identity
    isempty(strip(identity.case_id)) && throw(ContractError("snapshot case ID must not be empty"))
    expected_grid = _snapshot_grid_signature(geometry)
    geometry.grid_signature == expected_grid ||
        throw(ContractError("snapshot geometry signature does not match its content"))
    identity.grid_signature == expected_grid || throw(ContractError("snapshot grid signature mismatch"))
    identity.layout_signature == _snapshot_layout_signature(snapshot.counts, snapshot.physics) ||
        throw(ContractError("snapshot layout signature mismatch"))
    identity.physics_contract_hash == content_hash(snapshot.physics) ||
        throw(ContractError("snapshot physics contract hash mismatch"))
    identity.temperature_field_signature == content_id("temperature-field", snapshot.temperature) ||
        throw(ContractError("snapshot temperature signature mismatch"))
    identity.material_field_signature == content_id("material-field", snapshot.material_id) ||
        throw(ContractError("snapshot material signature mismatch"))
    identity.conductivity_field_signature == content_id("conductivity-field", snapshot.conductivity) ||
        throw(ContractError("snapshot conductivity signature mismatch"))

    expected_artifact_id = _snapshot_artifact_id(
        snapshot.counts,
        identity,
        snapshot.physics,
        snapshot.quality,
        snapshot.policy,
        snapshot.approval_record,
        snapshot.temperature_unit,
    )
    snapshot.envelope.artifact_id == expected_artifact_id ||
        throw(ContractError("snapshot artifact ID does not match its content"))
    return snapshot
end

function build_snapshot(counts::NTuple{16,Int},
                        temperature::AbstractArray{<:Real,3},
                        material_id::AbstractArray{<:Integer,3},
                        conductivity::AbstractArray{<:Real,3},
                        geometry::GridGeometry3D,
                        physics::PhysicsContract,
                        case_id::AbstractString,
                        layout_signature::AbstractString,
                        quality::SolveQuality,
                        policy::NumericalPolicy,
                        approval_record::ApprovalRecord;
                        run_id::AbstractString)::ThermalSnapshot
    temperature_array = Float64.(temperature)
    material_array = UInt8.(material_id)
    conductivity_array = Float64.(conductivity)
    identity = SnapshotIdentity(
        String(case_id),
        String(layout_signature),
        geometry.grid_signature,
        content_hash(physics),
        content_id("temperature-field", temperature_array),
        content_id("material-field", material_array),
        content_id("conductivity-field", conductivity_array),
    )
    artifact_id = _snapshot_artifact_id(
        counts, identity, physics, quality, policy, approval_record, :K,
    )
    envelope = ArtifactEnvelope(
        CURRENT_SCHEMA_VERSION, "snapshot", artifact_id, VERIFIED, String(run_id),
    )
    snapshot = ThermalSnapshot(
        envelope,
        counts,
        temperature_array,
        material_array,
        conductivity_array,
        geometry,
        identity,
        physics,
        quality,
        policy,
        approval_record,
        :K,
    )
    return validate_snapshot(snapshot)
end

function validate_snapshot_for_dataset(snapshot::ThermalSnapshot)::ThermalSnapshot
    snapshot.envelope.quality == LEGACY_UNVERIFIED &&
        throw(ContractError("LEGACY_UNVERIFIED snapshot cannot be promoted to a dataset"))
    return validate_snapshot(snapshot)
end
