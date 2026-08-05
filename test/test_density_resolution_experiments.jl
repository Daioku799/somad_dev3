using Test

include(joinpath(@__DIR__, "..", "H2-rom", "src", "DensityResolutionExperiments", "DensityResolutionExperiments.jl"))
using .DensityResolutionExperiments

@testset "density resolution experiment contracts" begin
    @test [cell_capacity(g) for g in (2, 4, 8, 16)] == [100, 25, 4, 1]

    masters = generate_master_occupancies(12; seed=1234)
    @test length(masters) == 12
    @test length(unique(master_signature.(masters))) == 12
    @test all(master -> size(master) == (16, 16), masters)
    @test all(master -> sum(master) == 16, masters)
    @test master_signature.(masters) ==
          master_signature.(generate_master_occupancies(12; seed=1234))

    for master in masters, g in (2, 4, 8, 16)
        mu, counts, capacities, block_means = coarsen_master_occupancy(master, g)
        @test size(counts) == (g, g)
        @test size(block_means) == (g, g)
        @test sum(counts) == 16
        @test round.(Int, reshape(mu, g, g) .* capacities) == counts
        @test all(0.0 .<= mu .<= 1.0)
    end

    coordinates = [
        (0.15e-3 + (i - 1) * 0.2e-3, 0.15e-3 + (j - 1) * 0.2e-3)
        for i in 1:4 for j in 1:4
    ]
    for g in (2, 4, 8, 16)
        mu, counts, capacities = encode_layout_density(coordinates, g)
        @test sum(counts) == 16
        @test round.(Int, reshape(mu, g, g) .* capacities) == counts
    end
end
