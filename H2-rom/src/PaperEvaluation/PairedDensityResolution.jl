module PairedDensityResolution

using Random

export MASTER_GRID_SIZE, TSV_COUNT, RESOLUTIONS
export generate_master_occupancy, aggregate_counts, counts_to_density

const MASTER_GRID_SIZE = 16
const TSV_COUNT = 16
const RESOLUTIONS = (2, 4, 8, 16)

"""
    generate_master_occupancy(master_id; seed=20260805)

Create a deterministic 16 x 16 integer occupancy map containing exactly 16 TSVs.
The first four IDs are representative layouts; later IDs are reproducible random
layouts.  This integer map is the common source for every density resolution.
"""
function generate_master_occupancy(master_id::Integer; seed::Integer=20260805)
    master_id > 0 || throw(ArgumentError("master_id must be positive"))

    occupancy = zeros(Int, MASTER_GRID_SIZE, MASTER_GRID_SIZE)

    if master_id == 1
        # Spatially uniform 4 x 4 lattice.
        for j in (2, 6, 10, 14), i in (2, 6, 10, 14)
            occupancy[i, j] = 1
        end
    elseif master_id == 2
        # Center-concentrated 4 x 4 block.
        occupancy[7:10, 7:10] .= 1
    elseif master_id == 3
        # Four 2 x 2 corner clusters.
        for js in (2:3, 14:15), is in (2:3, 14:15)
            occupancy[is, js] .= 1
        end
    elseif master_id == 4
        # Diagonal distribution spanning the chip.
        for i in 1:MASTER_GRID_SIZE
            occupancy[i, i] = 1
        end
    else
        rng = MersenneTwister(seed + master_id)
        selected = randperm(rng, MASTER_GRID_SIZE^2)[1:TSV_COUNT]
        occupancy[selected] .= 1
    end

    @assert sum(occupancy) == TSV_COUNT
    return occupancy
end

"""
    aggregate_counts(master, resolution)

Block-sum a 16 x 16 integer occupancy map to a coarser square grid.  Unlike
averaging continuous densities, this operation preserves the exact TSV count.
"""
function aggregate_counts(master::AbstractMatrix{<:Integer}, resolution::Integer)
    size(master) == (MASTER_GRID_SIZE, MASTER_GRID_SIZE) ||
        throw(DimensionMismatch("master must be $(MASTER_GRID_SIZE) x $(MASTER_GRID_SIZE)"))
    resolution in RESOLUTIONS ||
        throw(ArgumentError("resolution must be one of $(collect(RESOLUTIONS))"))

    block_size = div(MASTER_GRID_SIZE, resolution)
    counts = zeros(Int, resolution, resolution)
    for j in 1:resolution, i in 1:resolution
        i_range = ((i - 1) * block_size + 1):(i * block_size)
        j_range = ((j - 1) * block_size + 1):(j * block_size)
        counts[i, j] = sum(@view master[i_range, j_range])
    end

    @assert sum(counts) == sum(master)
    return counts
end

"""
    counts_to_density(counts, capacities)

Convert exact per-cell TSV counts to the density values consumed by the existing
layout generator.  The round trip `round.(density .* capacities)` must reproduce
the requested integer counts exactly.
"""
function counts_to_density(
    counts::AbstractMatrix{<:Integer},
    capacities::AbstractMatrix{<:Integer},
)
    size(counts) == size(capacities) ||
        throw(DimensionMismatch("counts and capacities must have the same shape"))
    any(capacities .<= 0) && throw(ArgumentError("all cell capacities must be positive"))
    any(counts .< 0) && throw(ArgumentError("counts must be nonnegative"))
    any(counts .> capacities) && throw(ArgumentError("counts exceed cell capacity"))

    density = Float64.(counts) ./ Float64.(capacities)
    round_trip = round.(Int, density .* capacities)
    round_trip == counts || error("density conversion did not preserve integer counts")
    return density
end

end
