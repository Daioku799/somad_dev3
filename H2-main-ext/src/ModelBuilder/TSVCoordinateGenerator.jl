module TSVCoordinateGenerator

using ..ConfigLoader.Types

export generate_tsv_coordinates

"""
    generate_tsv_coordinates(config::ModelConfig)

Generate TSV coordinates based on the density map in the configuration.
If tsv.mode is :manual, it returns the manual coordinates.
If tsv.mode is :density, it expands the density map into real coordinates.
"""
function generate_tsv_coordinates(config::ModelConfig)
    tsv = config.tsv
    if tsv.mode == :manual
        return tsv.coords
    elseif tsv.mode == :density
        return expand_density_map(config)
    else
        # fallback or empty
        return tsv.coords
    end
end

"""
    expand_density_map(config::ModelConfig)

Expand the density map into real TSV coordinates.
Implementation follows the requirements in 要件定義.md (4.7).
"""
function expand_density_map(config::ModelConfig)
    tsv = config.tsv
    gx, gy = tsv.gx, tsv.gy
    lx, ly = config.lx, config.ly
    density = tsv.density
    p_min = tsv.p_min
    m_edge = tsv.m_edge
    
    w_cell = lx / gx
    h_cell = ly / gy
    
    # Calculate max TSVs per cell
    # Add epsilon to handle floating point precision issues (e.g., 0.00027 / 0.00003 might be 8.999...)
    nx_cell = max(0, floor(Int, (w_cell - 2 * m_edge) / p_min + 1e-9) + 1)
    ny_cell = max(0, floor(Int, (h_cell - 2 * m_edge) / p_min + 1e-9) + 1)
    n_max_cell = nx_cell * ny_cell
    
    all_coords = Tuple{Float64, Float64}[]
    
    for j in 1:gy
        for i in 1:gx
            idx = (j - 1) * gx + i
            rho = density[idx]
            
            # n_ij = round(rho_ij * n_max,ij)
            n_target = round(Int, rho * n_max_cell)
            n_target = min(n_target, n_max_cell)
            
            if n_target <= 0
                continue
            end
            
            # Generate candidate points for this cell
            # Cell boundaries:
            x0 = (i - 1) * w_cell
            y0 = (j - 1) * h_cell
            
            # Center-aligned grid within the cell
            # Used area: (nx_cell - 1) * p_min
            # Free space in cell: w_cell - 2 * m_edge - (nx_cell - 1) * p_min
            # We add half of this free space as extra offset to center it.
            extra_ox = (w_cell - 2 * m_edge - (nx_cell - 1) * p_min) / 2
            extra_oy = (h_cell - 2 * m_edge - (ny_cell - 1) * p_min) / 2
            
            candidates = Tuple{Float64, Float64}[]
            for ky in 1:ny_cell
                for kx in 1:nx_cell
                    cx = x0 + m_edge + extra_ox + (kx - 1) * p_min
                    cy = y0 + m_edge + extra_oy + (ky - 1) * p_min
                    push!(candidates, (cx, cy))
                end
            end
            
            # Select n_target points closest to the center of the cell
            cell_center_x = x0 + w_cell / 2
            cell_center_y = y0 + h_cell / 2
            
            sort!(candidates, by = c -> (c[1] - cell_center_x)^2 + (c[2] - cell_center_y)^2)
            
            for k in 1:min(n_target, length(candidates))
                push!(all_coords, candidates[k])
            end
        end
    end
    
    # Final global constraint check (total max)
    if length(all_coords) > tsv.n_total_max
        # Keep only the first n_total_max
        # In a real scenario, we might want to prioritize differently, 
        # but for now, we just truncate or keep the first ones.
        return all_coords[1:tsv.n_total_max]
    end
    
    return all_coords
end

end # module
