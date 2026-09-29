function _finite_cell_temperature(cell_temperature_K::Real)::Float64
    temperature = Float64(cell_temperature_K)
    isfinite(temperature) || throw(ContractError("cell temperature must be finite"))
    return temperature
end
function boundary_heat_rate(bc::DirichletBoundary, face::BoundaryFace,
                            cell_temperature_K::Real)::Float64
    temperature = _finite_cell_temperature(cell_temperature_K)
    return bc.conductance_W_K * (temperature - bc.temperature_K)
end

function boundary_heat_rate(bc::NeumannBoundary, face::BoundaryFace,
                            cell_temperature_K::Real)::Float64
    _finite_cell_temperature(cell_temperature_K)
    return bc.outward_heat_flux_W_m2 * face.area_m2
end

function boundary_heat_rate(bc::RobinBoundary, face::BoundaryFace,
                            cell_temperature_K::Real)::Float64
    temperature = _finite_cell_temperature(cell_temperature_K)
    return bc.heat_transfer_coefficient_W_m2K * face.area_m2 *
           (temperature - bc.ambient_temperature_K)
end

"""Sum external heat rates after rejecting duplicate physical boundary faces."""
function aggregate_boundary_heat_rates(rates::AbstractVector{BoundaryHeatRate})::Float64
    seen = Set{Tuple{Symbol,NTuple{3,Int}}}()
    total = 0.0
    for rate in rates
        key = (rate.face.side, rate.face.cell_index)
        key in seen && throw(ContractError("duplicate boundary face: $key"))
        push!(seen, key)
        total += rate.heat_rate_W
    end
    isfinite(total) || throw(ContractError("aggregated boundary heat rate is non-finite"))
    return total
end
