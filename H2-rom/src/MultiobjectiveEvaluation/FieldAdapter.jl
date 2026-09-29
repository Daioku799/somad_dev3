function _expected_grid_signature(geometry::GridGeometry3D)::String
    return content_id("grid", (
        x_faces=geometry.x_faces,
        y_faces=geometry.y_faces,
        z_faces=geometry.z_faces,
        physical_ranges=geometry.physical_ranges,
    ))
end
function _expected_layout_signature(field::FieldBundle)::String
    return content_id("layout", (
        counts=field.counts,
        tsv_diameter_m=field.physics.tsv_diameter_m,
        min_pitch_m=field.physics.min_pitch_m,
        rule_version=field.physics.layout_rule_version,
    ))
end

function _require_nonempty_identity(label::AbstractString, value::AbstractString)
    isempty(strip(value)) && throw(ContractError("$label must not be empty"))
end

function validate_field_bundle(field::FieldBundle)::FieldBundle
    validate_physics_contract(field.physics)
    all(count -> 0 <= count <= 9, field.counts) ||
        throw(ContractError("all TSV counts must be in 0:9"))
    field.temperature_unit == :K || throw(ContractError("temperature unit must be K"))

    geometry = field.geometry
    expected_shape = (
        length(geometry.x_faces) - 1,
        length(geometry.y_faces) - 1,
        length(geometry.z_faces) - 1,
    )
    size(field.temperature) == expected_shape ||
        throw(ContractError("temperature shape does not match grid geometry"))
    size(field.material_id) == expected_shape ||
        throw(ContractError("material shape does not match grid geometry"))
    size(field.conductivity) == expected_shape ||
        throw(ContractError("conductivity shape does not match grid geometry"))
    physical_shape = ntuple(axis -> length(geometry.physical_ranges[axis]), 3)
    physical_shape == field.physics.metadata.grid_shape ||
        throw(ContractError("physical grid shape does not match PhysicsMetadata"))
    all(isfinite, field.temperature) || throw(ContractError("temperature field contains non-finite values"))
    all(isfinite, field.conductivity) ||
        throw(ContractError("conductivity field contains non-finite values"))

    identity = field.identity
    for (label, value) in (
        ("case_id", identity.case_id),
        ("layout_signature", identity.layout_signature),
        ("grid_signature", identity.grid_signature),
        ("physics_contract_hash", identity.physics_contract_hash),
        ("temperature_field_signature", identity.temperature_field_signature),
        ("material_field_signature", identity.material_field_signature),
        ("conductivity_field_signature", identity.conductivity_field_signature),
        ("objective_definition_id", identity.objective_definition_id),
    )
        _require_nonempty_identity(label, value)
    end

    expected_grid = _expected_grid_signature(geometry)
    geometry.grid_signature == expected_grid ||
        throw(ContractError("geometry grid signature does not match its content"))
    identity.grid_signature == expected_grid ||
        throw(ContractError("field identity grid signature mismatch"))
    identity.layout_signature == _expected_layout_signature(field) ||
        throw(ContractError("layout signature does not match integer counts and physics"))
    identity.physics_contract_hash == content_hash(field.physics) ||
        throw(ContractError("physics contract hash mismatch"))
    identity.temperature_field_signature == content_id("temperature-field", field.temperature) ||
        throw(ContractError("temperature field signature mismatch"))
    identity.material_field_signature == content_id("material-field", field.material_id) ||
        throw(ContractError("material field signature mismatch"))
    identity.conductivity_field_signature == content_id("conductivity-field", field.conductivity) ||
        throw(ContractError("conductivity field signature mismatch"))

    ids = field.physics.silicon_material_ids
    expected_k = field.physics.expected_silicon_conductivity_W_mK
    ranges = geometry.physical_ranges
    for k in ranges[3], j in ranges[2], i in ranges[1]
        isfinite(field.conductivity[i, j, k]) && field.conductivity[i, j, k] > 0.0 ||
            throw(ContractError("physical-cell conductivity must be finite and positive at ($i,$j,$k)"))
        material = field.material_id[i, j, k]
        position = findfirst(==(material), ids)
        position === nothing && continue
        isapprox(field.conductivity[i, j, k], expected_k[position]; rtol=1e-12, atol=0.0) ||
            throw(ContractError("silicon conductivity does not match PhysicsContract at ($i,$j,$k)"))
    end
    return field
end

function _cell_centers(geometry::GridGeometry3D)
    return (
        (geometry.x_faces[1:end-1] .+ geometry.x_faces[2:end]) ./ 2,
        (geometry.y_faces[1:end-1] .+ geometry.y_faces[2:end]) ./ 2,
        (geometry.z_faces[1:end-1] .+ geometry.z_faces[2:end]) ./ 2,
    )
end

function _coordinate(geometry::GridGeometry3D, index::CartesianIndex{3})::NTuple{3,Float64}
    centers = _cell_centers(geometry)
    return (centers[1][index[1]], centers[2][index[2]], centers[3][index[3]])
end
