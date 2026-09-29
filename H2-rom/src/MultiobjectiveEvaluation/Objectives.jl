function _evaluate_tmax_validated(field::FieldBundle)::TmaxResult
    ranges = field.geometry.physical_ranges
    best_value = -Inf
    best_index = CartesianIndex(first(ranges[1]), first(ranges[2]), first(ranges[3]))
    for k in ranges[3], j in ranges[2], i in ranges[1]
        value = field.temperature[i, j, k]
        if value > best_value
            best_value = value
            best_index = CartesianIndex(i, j, k)
        end
    end
    return TmaxResult(best_value, best_index, _coordinate(field.geometry, best_index), :K)
end

function evaluate_tmax(field::FieldBundle)::TmaxResult
    validate_field_bundle(field)
    return _evaluate_tmax_validated(field)
end

function _axis_gradient(field::FieldBundle, i::Int, j::Int, k::Int,
                        axis::Int)::Float64
    index = (i, j, k)
    if axis == 1
        minus, plus = (i - 1, j, k), (i + 1, j, k)
        faces = field.geometry.x_faces
        area = (field.geometry.y_faces[j + 1] - field.geometry.y_faces[j]) *
               (field.geometry.z_faces[k + 1] - field.geometry.z_faces[k])
    elseif axis == 2
        minus, plus = (i, j - 1, k), (i, j + 1, k)
        faces = field.geometry.y_faces
        area = (field.geometry.x_faces[i + 1] - field.geometry.x_faces[i]) *
               (field.geometry.z_faces[k + 1] - field.geometry.z_faces[k])
    elseif axis == 3
        minus, plus = (i, j, k - 1), (i, j, k + 1)
        faces = field.geometry.z_faces
        area = (field.geometry.x_faces[i + 1] - field.geometry.x_faces[i]) *
               (field.geometry.y_faces[j + 1] - field.geometry.y_faces[j])
    else
        throw(ContractError("gradient axis must be 1, 2, or 3"))
    end

    p = index[axis]
    p_center = (faces[p] + faces[p + 1]) / 2
    minus_center = (faces[p - 1] + faces[p]) / 2
    plus_center = (faces[p + 1] + faces[p + 2]) / 2
    d_p_minus = p_center - faces[p]
    d_n_minus = faces[p] - minus_center
    d_p_plus = faces[p + 1] - p_center
    d_n_plus = plus_center - faces[p + 1]

    temperature_p = field.temperature[index...]
    conductivity_p = field.conductivity[index...]
    conductance_minus = internal_face_conductance(
        area, d_p_minus, d_n_minus, conductivity_p, field.conductivity[minus...],
    )
    conductance_plus = internal_face_conductance(
        area, d_p_plus, d_n_plus, conductivity_p, field.conductivity[plus...],
    )
    gradient_minus = conductance_minus * (temperature_p - field.temperature[minus...]) /
                     (area * conductivity_p)
    gradient_plus = conductance_plus * (field.temperature[plus...] - temperature_p) /
                    (area * conductivity_p)
    return (d_p_plus * gradient_minus + d_p_minus * gradient_plus) /
           (d_p_minus + d_p_plus)
end

function _evaluate_gmax_validated(field::FieldBundle)::GmaxResult
    physical = field.geometry.physical_ranges
    interior = ntuple(axis -> (first(physical[axis]) + 1):(last(physical[axis]) - 1), 3)
    any(isempty, interior) &&
        throw(ContractError("no cells have six physical-cell neighbours for gmax"))
    silicon_ids = field.physics.silicon_material_ids

    found = false
    best_value = -Inf
    best_index = CartesianIndex(first(interior[1]), first(interior[2]), first(interior[3]))
    best_components = (0.0, 0.0, 0.0)
    for k in interior[3], j in interior[2], i in interior[1]
        field.material_id[i, j, k] in silicon_ids || continue
        components = (
            _axis_gradient(field, i, j, k, 1),
            _axis_gradient(field, i, j, k, 2),
            _axis_gradient(field, i, j, k, 3),
        )
        magnitude = sqrt(sum(abs2, components))
        isfinite(magnitude) || throw(ContractError("reconstructed gradient is non-finite"))
        if !found || magnitude > best_value
            found = true
            best_value = magnitude
            best_index = CartesianIndex(i, j, k)
            best_components = components
        end
    end
    found || throw(ContractError("gmax target mask is empty"))
    return GmaxResult(
        best_value,
        best_index,
        _coordinate(field.geometry, best_index),
        field.material_id[best_index],
        best_components,
        :K_per_m,
    )
end

function evaluate_gmax(field::FieldBundle)::GmaxResult
    validate_field_bundle(field)
    return _evaluate_gmax_validated(field)
end
