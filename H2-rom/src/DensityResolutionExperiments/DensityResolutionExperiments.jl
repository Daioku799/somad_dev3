module DensityResolutionExperiments

using Random

export cell_capacity,
       count_layout,
       encode_layout_density,
       coarsen_master_occupancy,
       generate_master_occupancies,
       master_signature

const DEFAULT_LX = 1.2e-3
const DEFAULT_LY = 1.2e-3
const DEFAULT_MARGIN = 0.1e-3
const DEFAULT_PITCH = 50e-6
const MASTER_RESOLUTION = 16

"""Return the number of pitch-constrained TSV sites in one `g × g` cell."""
function cell_capacity(
    g::Int;
    lx::Float64=DEFAULT_LX,
    ly::Float64=DEFAULT_LY,
    margin::Float64=DEFAULT_MARGIN,
    pitch::Float64=DEFAULT_PITCH,
)::Int
    g > 0 || throw(ArgumentError("g must be positive"))
    isapprox(lx, ly; atol=1e-15, rtol=0.0) ||
        throw(ArgumentError("only square implementation domains are supported"))

    cell_width = (lx - 2margin) / g
    guard = pitch / 2
    n_axis = floor(Int, (cell_width - 2guard + 1e-9) / pitch) + 1
    return max(n_axis, 0)^2
end

function coordinate_tuple(point)
    if hasproperty(point, :x) && hasproperty(point, :y)
        return Float64(getproperty(point, :x)), Float64(getproperty(point, :y))
    elseif point isa Tuple && length(point) == 2
        return Float64(point[1]), Float64(point[2])
    end
    throw(ArgumentError("coordinate must provide x and y or be a two-element tuple"))
end

"""Count a fixed physical TSV layout in a `g × g` density-map partition."""
function count_layout(
    coordinates,
    g::Int;
    lx::Float64=DEFAULT_LX,
    ly::Float64=DEFAULT_LY,
    margin::Float64=DEFAULT_MARGIN,
)::Matrix{Int}
    g > 0 || throw(ArgumentError("g must be positive"))
    x_span = lx - 2margin
    y_span = ly - 2margin
    x_span > 0 && y_span > 0 || throw(ArgumentError("invalid implementation domain"))

    counts = zeros(Int, g, g)
    for point in coordinates
        x, y = coordinate_tuple(point)
        margin <= x <= lx - margin || throw(ArgumentError("x=$x lies outside the implementation domain"))
        margin <= y <= ly - margin || throw(ArgumentError("y=$y lies outside the implementation domain"))
        i = clamp(floor(Int, (x - margin) / x_span * g) + 1, 1, g)
        j = clamp(floor(Int, (y - margin) / y_span * g) + 1, 1, g)
        counts[i, j] += 1
    end
    return counts
end

"""
Encode one unchanged physical layout as density features on a `g × g` grid.

The FVM geometry and temperature field do not change. Only the ROM input
representation changes, which is the defining condition of Experiment 1A.
"""
function encode_layout_density(coordinates, g::Int; kwargs...)
    counts = count_layout(coordinates, g; kwargs...)
    capacity = cell_capacity(g; kwargs...)
    capacity > 0 || throw(ArgumentError("g=$g has no feasible TSV sites per cell"))
    maximum(counts) <= capacity ||
        throw(ArgumentError("layout occupancy exceeds the g=$g cell capacity"))
    return vec(counts ./ capacity), counts, fill(capacity, g, g)
end

"""
Aggregate a 16×16 occupancy map to `g × g` while exactly preserving TSV count.

The arithmetic block mean is `counts / block_size^2`. The returned ROM/FVM
density uses `counts / physical_cell_capacity`, because the current placement
grid has 400 total sites at 2×2 and 4×4 but 256 at 8×8 and 16×16. This capacity
correction prevents the same master layout from changing its total TSV count.
"""
function coarsen_master_occupancy(master::AbstractMatrix{<:Integer}, g::Int; kwargs...)
    size(master) == (MASTER_RESOLUTION, MASTER_RESOLUTION) ||
        throw(DimensionMismatch("master occupancy must be 16×16"))
    MASTER_RESOLUTION % g == 0 || throw(ArgumentError("g must divide 16"))
    all(value -> value in (0, 1), master) ||
        throw(ArgumentError("master occupancy must be binary"))

    block_size = MASTER_RESOLUTION ÷ g
    counts = zeros(Int, g, g)
    for j in 1:g, i in 1:g
        i_range = (i - 1) * block_size + 1:i * block_size
        j_range = (j - 1) * block_size + 1:j * block_size
        counts[i, j] = sum(@view master[i_range, j_range])
    end

    capacity = cell_capacity(g; kwargs...)
    maximum(counts) <= capacity ||
        throw(ArgumentError("aggregated occupancy exceeds the g=$g cell capacity"))
    mu = counts ./ capacity
    block_means = counts ./ block_size^2
    return vec(mu), counts, fill(capacity, g, g), block_means
end

master_signature(master::AbstractMatrix{<:Integer}) = join(vec(master), "")

function occupancy_from_indices(indices::AbstractVector{Int})
    master = zeros(Int, MASTER_RESOLUTION, MASTER_RESOLUTION)
    master[indices] .= 1
    return master
end

"""Generate deterministic, unique 16×16 master layouts with 16 occupied cells."""
function generate_master_occupancies(
    n_masters::Int;
    n_tsv::Int=16,
    seed::Int=20260805,
)::Vector{Matrix{Int}}
    n_masters > 0 || throw(ArgumentError("n_masters must be positive"))
    0 < n_tsv <= MASTER_RESOLUTION^2 || throw(ArgumentError("invalid n_tsv"))

    all_indices = vec(collect(CartesianIndices((MASTER_RESOLUTION, MASTER_RESOLUTION))))
    center = (MASTER_RESOLUTION + 1) / 2
    radial_order = sortperm(all_indices; by=idx -> (
        (idx[1] - center)^2 + (idx[2] - center)^2,
        idx[1],
        idx[2],
    ))

    masters = Matrix{Int}[]
    seen = Set{String}()

    function add_master!(master)
        sum(master) == n_tsv || return
        signature = master_signature(master)
        signature in seen && return
        push!(seen, signature)
        push!(masters, master)
    end

    if n_tsv == 16
        uniform_axis = [2, 6, 11, 15]
        linear_indices = LinearIndices((MASTER_RESOLUTION, MASTER_RESOLUTION))
        uniform_indices = [linear_indices[CartesianIndex(i, j)] for i in uniform_axis for j in uniform_axis]
        add_master!(occupancy_from_indices(uniform_indices))
    end

    linear_indices = LinearIndices((MASTER_RESOLUTION, MASTER_RESOLUTION))
    center_indices = [linear_indices[index] for index in all_indices[radial_order[1:n_tsv]]]
    corner_indices = [linear_indices[index] for index in all_indices[radial_order[end-n_tsv+1:end]]]
    add_master!(occupancy_from_indices(center_indices))
    add_master!(occupancy_from_indices(corner_indices))

    rng = MersenneTwister(seed)
    while length(masters) < n_masters
        add_master!(occupancy_from_indices(randperm(rng, MASTER_RESOLUTION^2)[1:n_tsv]))
    end
    return masters[1:n_masters]
end

end
