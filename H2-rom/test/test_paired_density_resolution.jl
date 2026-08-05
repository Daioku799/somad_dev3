using Test

include(joinpath(@__DIR__, "..", "src", "PaperEvaluation", "PairedDensityResolution.jl"))
using .PairedDensityResolution

@testset "Paired density-resolution inputs" begin
    masters = [generate_master_occupancy(master_id) for master_id in 1:50]

    @test all(size(master) == (16, 16) for master in masters)
    @test all(sum(master) == 16 for master in masters)
    @test length(unique(vec(master) for master in masters)) == 50

    capacities = Dict(
        2 => fill(100, 2, 2),
        4 => fill(25, 4, 4),
        8 => fill(4, 8, 8),
        16 => fill(1, 16, 16),
    )

    for master in masters, resolution in RESOLUTIONS
        counts = aggregate_counts(master, resolution)
        density = counts_to_density(counts, capacities[resolution])

        @test sum(counts) == 16
        @test round.(Int, density .* capacities[resolution]) == counts
        @test all(0.0 .<= density .<= 1.0)
    end

    @test_throws ArgumentError generate_master_occupancy(0)
    @test_throws ArgumentError aggregate_counts(masters[1], 3)
    @test_throws DimensionMismatch aggregate_counts(zeros(Int, 8, 8), 8)
    @test_throws ArgumentError counts_to_density(fill(2, 2, 2), fill(1, 2, 2))
end
