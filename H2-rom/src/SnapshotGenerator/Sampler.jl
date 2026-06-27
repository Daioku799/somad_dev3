module Sampler

using LatinHypercubeSampling
using Distributions
using Random

# Load H2-main-ext modules via a wrapper module to support relative imports (..ConfigLoader)
module H2MainExt
    const SRC_DIR = abspath(joinpath(@__DIR__, "../../../H2-main-ext/src"))
    include(joinpath(SRC_DIR, "ConfigLoader/ConfigLoader.jl"))
    using .ConfigLoader
    include(joinpath(SRC_DIR, "ComponentGenerator/ComponentGenerator.jl"))
    using .ComponentGenerator
end

using .H2MainExt.ComponentGenerator
using .H2MainExt.ConfigLoader

export TSVParams, generate_samples, validate_params

struct TSVParams
    radius::Float64
    count::Int
    coords::Vector{Tuple{Float64, Float64}}
end

"""
    generate_samples(n_cases::Int; n_tsv_fixed=16)

Generate n_cases of TSVParams using Latin Hypercube Sampling.
"""
function generate_samples(n_cases::Int; n_tsv_fixed=16)
    dims = 1 + 2 * n_tsv_fixed
    
    # LatinHypercubeSampling.jl randomLHC returns a Matrix{Int} in 1:n_cases
    plan = randomLHC(n_cases, dims)
    # Convert to Float64 in [0, 1]
    plan_norm = (plan .- 0.5) ./ n_cases
    
    r_dist = Uniform(15e-6, 40e-6)
    c_dist = Uniform(0.1e-3, 1.1e-3)
    
    samples = TSVParams[]
    
    for i in 1:n_cases
        r = quantile(r_dist, plan_norm[i, 1])
        coords = Tuple{Float64, Float64}[]
        for j in 1:n_tsv_fixed
            x = quantile(c_dist, plan_norm[i, 1 + (j-1)*2 + 1])
            y = quantile(c_dist, plan_norm[i, 1 + (j-1)*2 + 2])
            push!(coords, (x, y))
        end
        
        p = TSVParams(r, n_tsv_fixed, coords)
        
        # Validation and retry
        max_retries = 20
        attempt = 1
        while !validate_params(p) && attempt < max_retries
            # Re-sample coordinates for this case if invalid
            new_coords = Tuple{Float64, Float64}[]
            for j in 1:n_tsv_fixed
                push!(new_coords, (rand(c_dist), rand(c_dist)))
            end
            p = TSVParams(r, n_tsv_fixed, new_coords)
            attempt += 1
        end
        
        push!(samples, p)
    end
    
    return samples
end

function validate_params(p::TSVParams)
    chip_min, chip_max = 0.0, 1.2e-3
    buffer = p.radius + 1e-6
    
    for (i, c1) in enumerate(p.coords)
        if c1[1] - buffer < chip_min || c1[1] + buffer > chip_max ||
           c1[2] - buffer < chip_min || c1[2] + buffer > chip_max
            return false
        end
        for j in i+1:length(p.coords)
            c2 = p.coords[j]
            dist = sqrt((c1[1]-c2[1])^2 + (c1[2]-c2[2])^2)
            if dist < 2 * p.radius + 1e-6
                return false
            end
        end
    end
    return true
end

"""
    generate_samples(n_samples::Int, grid_size::Tuple{Int, Int}; n_limit::Int) -> Vector{Vector{Float64}}

Generate density map samples using Latin Hypercube Sampling (LHS).
The density values are continuous in [0, 1].
"""
function generate_samples(n_samples::Int, grid_size::Tuple{Int, Int}; n_limit::Int, include_representative::Bool=true)
    dims = grid_size[1] * grid_size[2]
    
    # Perform LHS sampling
    plan = randomLHC(n_samples, dims)
    
    # Scale to continuous values in [0, 1]
    plan_norm = (plan .- rand(Float64, size(plan))) ./ n_samples
    
    # Convert Matrix to Vector{Vector{Float64}}
    samples = [plan_norm[i, :] for i in 1:n_samples]
    
    if include_representative
        cx = (grid_size[1] + 1) / 2
        cy = (grid_size[2] + 1) / 2
        d_max = sqrt((cx - 1)^2 + (cy - 1)^2)
        
        # 1. Uniform
        if n_samples >= 1
            samples[1] = fill(1.0, dims)
        end
        # 2. Center-concentrated
        if n_samples >= 2
            if d_max > 0.0
                samples[2] = vec([clamp(1.0 - sqrt((i - cx)^2 + (j - cy)^2) / d_max, 0.0, 1.0) for i in 1:grid_size[1], j in 1:grid_size[2]])
            else
                samples[2] = fill(1.0, dims)
            end
        end
        # 3. Corners-concentrated
        if n_samples >= 3
            if d_max > 0.0
                samples[3] = vec([clamp(sqrt((i - cx)^2 + (j - cy)^2) / d_max, 0.0, 1.0) for i in 1:grid_size[1], j in 1:grid_size[2]])
            else
                samples[3] = fill(1.0, dims)
            end
        end
    end
    
    if n_limit > 0
        # Use default constants from H2-main-ext
        r_tsv = H2MainExt.ConfigLoader.Defaults.R_TSV
        lx = H2MainExt.ConfigLoader.Defaults.LX
        ly = H2MainExt.ConfigLoader.Defaults.LY
        p_min = 2.0 * r_tsv + 10e-6 # 50e-6 pitch
        
        density = DensityMapConfig(grid_size[1], grid_size[2], Float64[], 0, n_limit, 1.0, Tuple{Int, Int}[])
        manufacturing = ManufacturingConfig(2.0 * r_tsv, p_min, 0.0, 0.0)
        tsv_config = TSVConfig(:density, Tuple{Float64, Float64}[], r_tsv, 0.1e-3, density, manufacturing, nothing)
        
        n_max_matrix = ComponentGenerator.Layout.get_cell_capacities(tsv_config, lx, ly)
        
        for i in 1:n_samples
            samples[i] = ComponentGenerator.Layout.adjust_density_constraints(samples[i], n_max_matrix, n_limit)
        end
    end
    
    return samples
end
end # module

