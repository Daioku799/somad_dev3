using Test

# Load H2-main-ext modules via a wrapper module to support relative imports (..ConfigLoader)
module H2MainExt
    const SRC_DIR = abspath(joinpath(@__DIR__, "../../H2-main-ext/src"))
    include(joinpath(SRC_DIR, "ConfigLoader/ConfigLoader.jl"))
    using .ConfigLoader
    include(joinpath(SRC_DIR, "ComponentGenerator/ComponentGenerator.jl"))
    using .ComponentGenerator
end

using .H2MainExt.ComponentGenerator
using .H2MainExt.ConfigLoader


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

@testset "Sampler generate_samples Constraints Test" begin
    n_samples = 5
    grid_size = (4, 4)
    n_limit = 5

    # Reconstruct TSVConfig to calculate get_cell_capacities
    r_tsv = 0.02e-3
    p_min = 0.05e-3
    lx = 1.2e-3
    ly = 1.2e-3

    density = DensityMapConfig(grid_size[1], grid_size[2], Float64[], 0, n_limit, 1.0, Tuple{Int, Int}[])
    manufacturing = ManufacturingConfig(2.0 * r_tsv, p_min, 0.0, 0.0)
    tsv_config = TSVConfig(:density, Tuple{Float64, Float64}[], r_tsv, 0.1e-3, density, manufacturing, nothing)

    n_max_matrix = ComponentGenerator.Layout.get_cell_capacities(tsv_config, lx, ly)
    n_max_flat = vec(n_max_matrix)

    # Generate samples with constraint
    samples = generate_samples(n_samples, grid_size; n_limit=n_limit)

    @test length(samples) == n_samples
    for s in samples
        sum_n = sum(round(Int, s[k] * n_max_flat[k]) for k in eachindex(s))
        @test sum_n <= n_limit
    end
end


