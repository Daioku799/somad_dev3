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

@testset "Sampler Representative Patterns Test" begin
    n_samples = 5
    grid_size = (4, 4)
    
    # 1. Without density limits (n_limit = 0)
    # The function signature will be updated to accept include_representative
    samples = generate_samples(n_samples, grid_size; n_limit=0, include_representative=true)
    
    @test length(samples) == n_samples
    
    # The first three samples should be representative patterns
    s_uni = samples[1]
    s_ctr = samples[2]
    s_crn = samples[3]
    
    # Uniform: all values are approximately equal
    @test all(x -> isapprox(x, s_uni[1], atol=1e-5), s_uni)
    @test s_uni[1] > 0.0
    
    # Center-concentrated: center cells (2,2), (2,3), (3,2), (3,3) are larger than corners
    m_ctr = reshape(s_ctr, 4, 4)
    @test m_ctr[2, 2] > m_ctr[1, 1]
    @test m_ctr[2, 3] > m_ctr[4, 4]
    
    # Corners-concentrated: corners are larger than center cells
    m_crn = reshape(s_crn, 4, 4)
    @test m_crn[1, 1] > m_crn[2, 2]
    @test m_crn[4, 4] > m_crn[2, 3]
    
    # 2. With density limits (n_limit > 0)
    n_limit = 80
    samples_lim = generate_samples(n_samples, grid_size; n_limit=n_limit, include_representative=true)
    @test length(samples_lim) == n_samples
    
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
    
    for s in samples_lim
        sum_n = sum(round(Int, s[k] * n_max_flat[k]) for k in eachindex(s))
        @test sum_n <= n_limit
    end
    
    # Representative patterns should maintain their qualitative features after adjustment
    m_ctr_lim = reshape(samples_lim[2], 4, 4)
    @test m_ctr_lim[2, 2] >= m_ctr_lim[1, 1]
    m_crn_lim = reshape(samples_lim[3], 4, 4)
    @test m_crn_lim[1, 1] >= m_crn_lim[2, 2]
end



