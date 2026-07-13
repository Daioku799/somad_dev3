module ConstraintManager

using ..H2MainExt.ConfigLoader: ModelConfig
using ..H2MainExt.ComponentGenerator.Layout: get_cell_capacities, adjust_density_constraints

export adjust_constraints!

"""
    adjust_constraints!(mu::Vector{Float64}, config)

Adjust the density map vector `mu` in place to comply with physical and density constraints.
1. Clamps each `mu_i` to `[0.0, 1.0]`.
2. Scales the density map if the total TSV count exceeds the specified maximum (`n_max` from `DensityMapConfig`).
"""
function apply_constraints!(mu::Vector{Float64}, config, rho_max, forbidden_zones, gx)
    # 1. Clamp each element to [0.0, rho_max] in-place
    for i in eachindex(mu)
        if isnan(mu[i]) || isinf(mu[i])
            continue
        end
        mu[i] = clamp(mu[i], 0.0, rho_max)
    end

    # 2. Zero out prohibited cells (forbidden zones)
    if config.tsv.mode == :density && config.tsv.density !== nothing
        for (ci, cj) in forbidden_zones
            # Julia uses column-major indexing: flat_idx = (cj - 1) * gx + ci
            idx = (cj - 1) * gx + ci
            if 1 <= idx <= length(mu)
                mu[idx] = 0.0
            end
        end
    end

    # 3. Invoke ComponentGenerator.Layout.adjust_density_constraints
    if config.tsv.mode == :density && config.tsv.density !== nothing
        # Get cell capacities matrix using layout logic
        n_max_matrix = get_cell_capacities(config.tsv, config.lx, config.ly)
        
        # Get maximum total TSVs allowed
        N_limit = config.tsv.density.n_max
        
        if N_limit > 0
            adjusted_mu = adjust_density_constraints(mu, n_max_matrix, N_limit)
            # Update mu in-place
            mu .= adjusted_mu
        end
    end
    return mu
end

function adjust_constraints!(mu::Vector{Float64}, config)
    # Default values
    rho_max = 1.0
    forbidden_zones = Tuple{Int, Int}[]
    gx = 1
    
    if config.tsv.mode == :density && config.tsv.density !== nothing
        rho_max = config.tsv.density.rho_cell_max
        forbidden_zones = config.tsv.density.prohibited_cells
        gx = config.tsv.density.gx
    end

    # Check if the individual is invalid (e.g. all elements are 0, NaN, or Inf)
    is_invalid(x) = !isempty(x) && (any(isnan, x) || any(isinf, x) || all(v -> v < 1e-9, x))

    # If the input is already invalid (e.g. contains NaN/Inf), pre-resample it
    # to avoid errors during constraint application.
    if is_invalid(mu)
        for i in eachindex(mu)
            mu[i] = rand() * rho_max
        end
    end

    # Apply constraints once
    apply_constraints!(mu, config, rho_max, forbidden_zones, gx)

    max_attempts = 100
    attempt = 0
    while is_invalid(mu) && attempt < max_attempts
        attempt += 1
        # Resample mu
        for i in eachindex(mu)
            mu[i] = rand() * rho_max
        end
        apply_constraints!(mu, config, rho_max, forbidden_zones, gx)
    end

    if is_invalid(mu)
        error("Failed to generate a valid density map satisfying constraints after $max_attempts attempts.")
    end
    
    return mu
end

end # module
