module Sampler

using LatinHypercubeSampling
using Distributions
using Random

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

end # module
