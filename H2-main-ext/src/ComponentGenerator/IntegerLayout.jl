"""Canonical expansion of 4x4 row-major integer TSV counts."""
module IntegerLayout

using ..ResearchContracts

export IntegerLayoutSpec, VerifiedLayout, expand_integer_counts

struct IntegerLayoutSpec
    counts::NTuple{16,Int}
    tsv_diameter_m::Float64
    min_pitch_m::Float64
    rule_version::String

    function IntegerLayoutSpec(counts::NTuple{16,Int}, tsv_diameter_m::Real,
                               min_pitch_m::Real, rule_version::AbstractString)
        all(count -> 0 <= count <= 9, counts) ||
            throw(ContractError("each integer TSV count must be in 0:9"))
        diameter = Float64(tsv_diameter_m)
        pitch = Float64(min_pitch_m)
        isfinite(diameter) && diameter > 0.0 ||
            throw(ContractError("TSV diameter must be finite and positive"))
        isfinite(pitch) && pitch > 0.0 ||
            throw(ContractError("minimum pitch must be finite and positive"))
        pitch >= diameter || throw(ContractError("minimum pitch must not be smaller than TSV diameter"))
        isempty(strip(rule_version)) && throw(ContractError("layout rule version must not be empty"))
        new(counts, diameter, pitch, String(rule_version))
    end
end
struct VerifiedLayout
    spec::IntegerLayoutSpec
    coordinates_m::Vector{NTuple{2,Float64}}
    layout_signature::String
    physical_signature::String
end

function _validate_total(total::Int;
                         required_total::Union{Nothing,Integer}=nothing,
                         allowed_total::Union{Nothing,AbstractUnitRange{<:Integer}}=nothing)
    required_total !== nothing && allowed_total !== nothing &&
        throw(ContractError("required_total and allowed_total are mutually exclusive"))
    required_total !== nothing && total != required_total &&
        throw(ContractError("TSV total $total does not equal required total $required_total"))
    allowed_total !== nothing && !(total in allowed_total) &&
        throw(ContractError("TSV total $total is outside allowed range $allowed_total"))
    return total
end

function _cell_candidates(row::Int, column::Int, lx::Float64, ly::Float64,
                          margin::Float64, pitch::Float64)
    usable_x = lx - 2margin
    usable_y = ly - 2margin
    cell_width = usable_x / 4
    cell_height = usable_y / 4
    x_min = margin + (column - 1) * cell_width
    x_max = x_min + cell_width
    y_min = margin + (row - 1) * cell_height
    y_max = y_min + cell_height
    center_x = (x_min + x_max) / 2
    center_y = (y_min + y_max) / 2

    candidates = NamedTuple[]
    for y_index in -1:1, x_index in -1:1
        x = center_x + x_index * pitch
        y = center_y + y_index * pitch
        x_min <= x <= x_max && y_min <= y <= y_max || continue
        push!(candidates, (
            distance2=(x - center_x)^2 + (y - center_y)^2,
            y_index=y_index,
            x_index=x_index,
            coordinate=(x, y),
        ))
    end
    sort!(candidates, by=candidate ->
        (candidate.distance2, candidate.y_index, candidate.x_index))
    return candidates
end

function _validate_physical_coordinates(coordinates::Vector{NTuple{2,Float64}},
                                        spec::IntegerLayoutSpec,
                                        lx::Float64, ly::Float64,
                                        margin::Float64)
    radius = spec.tsv_diameter_m / 2
    tolerance = 10eps(max(lx, ly, spec.min_pitch_m))
    for (index, (x, y)) in enumerate(coordinates)
        isfinite(x) && isfinite(y) || throw(ContractError("coordinate $index is non-finite"))
        margin + radius - tolerance <= x <= lx - margin - radius + tolerance ||
            throw(ContractError("coordinate $index violates the x implementation boundary"))
        margin + radius - tolerance <= y <= ly - margin - radius + tolerance ||
            throw(ContractError("coordinate $index violates the y implementation boundary"))
    end
    for i in eachindex(coordinates), j in (i + 1):length(coordinates)
        distance = hypot(
            coordinates[i][1] - coordinates[j][1],
            coordinates[i][2] - coordinates[j][2],
        )
        distance + tolerance >= spec.min_pitch_m ||
            throw(ContractError("coordinates $i and $j violate the minimum pitch"))
    end
    return coordinates
end

"""
    expand_integer_counts(spec, lx, ly; margin_m=0.1e-3, required_total=nothing,
                          allowed_total=nothing)

Expand a row-major 4x4 integer count vector without rounding or rescaling.
"""
function expand_integer_counts(spec::IntegerLayoutSpec, lx_m::Real, ly_m::Real;
                               margin_m::Real=0.1e-3,
                               required_total::Union{Nothing,Integer}=nothing,
                               allowed_total::Union{Nothing,AbstractUnitRange{<:Integer}}=nothing)::VerifiedLayout
    lx = Float64(lx_m)
    ly = Float64(ly_m)
    margin = Float64(margin_m)
    all(value -> isfinite(value) && value > 0.0, (lx, ly, margin)) ||
        throw(ContractError("layout dimensions and margin must be finite and positive"))
    2margin < lx && 2margin < ly || throw(ContractError("margin leaves no implementation domain"))

    total = _validate_total(sum(spec.counts); required_total=required_total,
                            allowed_total=allowed_total)
    coordinates = NTuple{2,Float64}[]
    for row in 1:4, column in 1:4
        cell_index = (row - 1) * 4 + column
        count = spec.counts[cell_index]
        candidates = _cell_candidates(row, column, lx, ly, margin, spec.min_pitch_m)
        length(candidates) >= count ||
            throw(ContractError("cell $cell_index cannot realize $count TSVs at the required pitch"))
        append!(coordinates, (candidates[index].coordinate for index in 1:count))
    end
    length(coordinates) == total || throw(ContractError("generated TSV count differs from integer input"))
    _validate_physical_coordinates(coordinates, spec, lx, ly, margin)

    layout_signature = content_id("layout", (
        counts=spec.counts,
        tsv_diameter_m=spec.tsv_diameter_m,
        min_pitch_m=spec.min_pitch_m,
        rule_version=spec.rule_version,
    ))
    physical_signature = content_id("physical-layout", (
        coordinates_m=sort(copy(coordinates)),
        lx_m=lx,
        ly_m=ly,
        margin_m=margin,
        tsv_diameter_m=spec.tsv_diameter_m,
        min_pitch_m=spec.min_pitch_m,
        rule_version=spec.rule_version,
    ))
    return VerifiedLayout(spec, coordinates, layout_signature, physical_signature)
end

end
