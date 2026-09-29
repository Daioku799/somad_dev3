"""
    internal_face_conductance(area, d_p, d_n, k_p, k_n)

Return the conductance of one internal face joining two physical cells. `d_p`
and `d_n` are the positive center-to-face distances. External boundary and
ghost-cell data are outside this function's contract.
"""
function internal_face_conductance(area::Real, d_p::Real, d_n::Real,
                                   k_p::Real, k_n::Real)::Float64
    area_value = _require_positive_finite("internal face area", area)
    d_p_value = _require_positive_finite("P center-to-face distance", d_p)
    d_n_value = _require_positive_finite("N center-to-face distance", d_n)
    k_p_value = _require_positive_finite("P conductivity", k_p)
    k_n_value = _require_positive_finite("N conductivity", k_n)

    conductance = area_value / (d_p_value / k_p_value + d_n_value / k_n_value)
    isfinite(conductance) && conductance > 0.0 ||
        throw(ContractError("internal face conductance is non-finite or non-positive"))
    return conductance
end
