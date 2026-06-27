using Test

include("../src/SnapshotGenerator/SnapshotGenerator.jl")
using .SnapshotGenerator.Sampler: generate_samples

@testset "Sampler generate_samples Test" begin
    n_samples = 5
    grid_size = (4, 4)
    n_limit = 10
    
    samples = generate_samples(n_samples, grid_size; n_limit=n_limit)
    
    @test samples isa Vector{Vector{Float64}}
    @test length(samples) == n_samples
    
    for s in samples
        @test length(s) == grid_size[1] * grid_size[2]
        @test all(x -> 0.0 <= x <= 1.0, s)
    end
end
