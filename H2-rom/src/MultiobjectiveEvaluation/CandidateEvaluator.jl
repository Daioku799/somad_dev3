function evaluate_objectives(field::FieldBundle)::ObjectiveEvaluation
    validate_field_bundle(field)
    tmax = _evaluate_tmax_validated(field)
    gmax = _evaluate_gmax_validated(field)
    return ObjectiveEvaluation(
        tmax.value_K,
        gmax.value_K_per_m,
        sum(field.counts),
        tmax.index,
        tmax.coordinate_m,
        gmax.index,
        gmax.coordinate_m,
        gmax.material_id,
        gmax.components_K_per_m,
        field.identity,
        tmax.unit,
        gmax.unit,
    )
end
