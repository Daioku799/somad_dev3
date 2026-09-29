const BOUNDARY_SIDES = (:xminus, :xplus, :yminus, :yplus, :zminus, :zplus)

function _require_positive_finite(label::AbstractString, value::Real)::Float64
    converted = Float64(value)
    isfinite(converted) && converted > 0.0 ||
        throw(ContractError("$label must be finite and positive"))
    return converted
end
struct GridGeometry3D
    x_faces::Vector{Float64}
    y_faces::Vector{Float64}
    z_faces::Vector{Float64}
    physical_ranges::NTuple{3,UnitRange{Int}}
    grid_signature::String

    function GridGeometry3D(x_faces::AbstractVector{<:Real},
                            y_faces::AbstractVector{<:Real},
                            z_faces::AbstractVector{<:Real},
                            physical_ranges::NTuple{3,UnitRange{Int}},
                            grid_signature::AbstractString)
        faces = (Float64.(x_faces), Float64.(y_faces), Float64.(z_faces))
        for (axis, values) in zip((:x, :y, :z), faces)
            length(values) >= 2 || throw(ContractError("$axis faces require at least two values"))
            all(isfinite, values) || throw(ContractError("$axis faces contain non-finite values"))
            all(diff(values) .> 0.0) || throw(ContractError("$axis faces must be strictly increasing"))
        end
        for (axis, range, values) in zip((:x, :y, :z), physical_ranges, faces)
            isempty(range) && throw(ContractError("$axis physical range must not be empty"))
            first(range) >= 1 && last(range) <= length(values) - 1 ||
                throw(ContractError("$axis physical range is outside the cell domain"))
        end
        isempty(strip(grid_signature)) && throw(ContractError("grid_signature must not be empty"))
        new(faces..., physical_ranges, String(grid_signature))
    end
end

struct BoundaryFace
    side::Symbol
    cell_index::NTuple{3,Int}
    area_m2::Float64
    center_distance_m::Float64

    function BoundaryFace(side::Symbol, cell_index::NTuple{3,Int}, area_m2::Real,
                          center_distance_m::Real)
        side in BOUNDARY_SIDES || throw(ContractError("unsupported boundary side: $side"))
        all(>(0), cell_index) || throw(ContractError("boundary cell index must be positive"))
        new(
            side,
            cell_index,
            _require_positive_finite("boundary face area", area_m2),
            _require_positive_finite("boundary center distance", center_distance_m),
        )
    end
end

abstract type AbstractBoundaryCondition end

struct DirichletBoundary <: AbstractBoundaryCondition
    temperature_K::Float64
    conductance_W_K::Float64
    function DirichletBoundary(temperature_K::Real, conductance_W_K::Real)
        temperature = Float64(temperature_K)
        isfinite(temperature) || throw(ContractError("boundary temperature must be finite"))
        new(temperature, _require_positive_finite("boundary conductance", conductance_W_K))
    end
end

struct NeumannBoundary <: AbstractBoundaryCondition
    outward_heat_flux_W_m2::Float64
    function NeumannBoundary(outward_heat_flux_W_m2::Real)
        flux = Float64(outward_heat_flux_W_m2)
        isfinite(flux) || throw(ContractError("outward heat flux must be finite"))
        new(flux)
    end
end

struct RobinBoundary <: AbstractBoundaryCondition
    heat_transfer_coefficient_W_m2K::Float64
    ambient_temperature_K::Float64
    function RobinBoundary(heat_transfer_coefficient_W_m2K::Real,
                           ambient_temperature_K::Real)
        ambient = Float64(ambient_temperature_K)
        isfinite(ambient) || throw(ContractError("ambient temperature must be finite"))
        new(
            _require_positive_finite(
                "heat-transfer coefficient",
                heat_transfer_coefficient_W_m2K,
            ),
            ambient,
        )
    end
end

struct BoundaryHeatRate
    face::BoundaryFace
    heat_rate_W::Float64
    function BoundaryHeatRate(face::BoundaryFace, heat_rate_W::Real)
        value = Float64(heat_rate_W)
        isfinite(value) || throw(ContractError("boundary heat rate must be finite"))
        new(face, value)
    end
end

struct EnergyBalanceResult
    generated_heat_W::Float64
    boundary_heat_rates_W::Vector{Float64}
    heat_in_W::Float64
    heat_out_W::Float64
    relative_imbalance::Float64
end

@enum SolveStatus PASS FAIL

struct SolveQuality
    status::SolveStatus
    converged::Bool
    final_relative_residual::Float64
    energy_relative_imbalance::Float64
    policy_id::String
    reasons::Vector{String}
end
