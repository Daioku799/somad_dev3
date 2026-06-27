module Layout

using ..Types: Point2D
using ...ConfigLoader: TSVConfig

export expand_coordinates, get_cell_capacities, adjust_density_constraints

"""
    expand_coordinates(config::TSVConfig, lx::Float64, ly::Float64) -> Vector{Point2D}

Expand coordinates list based on configuration, applying density-map centering layout
if mode is `:density`.
"""
function expand_coordinates(config::TSVConfig, lx::Float64, ly::Float64)
    if config.mode == :density
        if config.density === nothing || config.manufacturing === nothing
            return Point2D[]
        end
        
        gx = config.density.gx
        gy = config.density.gy
        p_min = config.manufacturing.p_min
        
        # 1. Calculate capacities of each cell
        n_max_matrix = get_cell_capacities(config, lx, ly)
        
        # 2. Adjust density constraints if total capacity/N_limit constraint is active
        mu = config.density.mu
        N_limit = config.density.n_max
        if N_limit > 0
            mu = adjust_density_constraints(mu, n_max_matrix, N_limit)
        end
        
        # 3. Place TSVs in each cell
        pts = Point2D[]
        g = p_min / 2.0
        
        # Reshape mu to gx x gy matrix for easy indexing (Julia is column-major)
        mu_matrix = reshape(mu, gx, gy)
        
        for j in 1:gy
            for i in 1:gx
                mu_val = mu_matrix[i, j]
                n_max_ij = n_max_matrix[i, j]
                n_ij = round(Int, mu_val * n_max_ij)
                
                if n_ij <= 0
                    continue
                end
                
                # Cell bounds
                x_min = (i - 1) * (lx / gx)
                x_max = i * (lx / gx)
                y_min = (j - 1) * (ly / gy)
                y_max = j * (ly / gy)
                
                # Maximum rows/columns inside the cell
                Nx = floor(Int, (x_max - x_min - 2.0 * g) / p_min) + 1
                Ny = floor(Int, (y_max - y_min - 2.0 * g) / p_min) + 1
                
                if Nx <= 0 || Ny <= 0
                    continue
                end
                
                # Spacing offset to center the grid inside the cell
                dx = ((x_max - x_min - 2.0 * g) - (Nx - 1) * p_min) / 2.0
                dy = ((y_max - y_min - 2.0 * g) - (Ny - 1) * p_min) / 2.0
                
                # Generate all grid coordinate candidates
                cell_pts = Point2D[]
                for v in 1:Ny
                    for u in 1:Nx
                        xu = x_min + g + dx + (u - 1) * p_min
                        yv = y_min + g + dy + (v - 1) * p_min
                        push!(cell_pts, Point2D(xu, yv))
                    end
                end
                
                # Center of the cell
                cx = (x_min + x_max) / 2.0
                cy = (y_min + y_max) / 2.0
                
                # Sort candidates by distance to the cell center
                sort!(cell_pts, by = p -> (p.x - cx)^2 + (p.y - cy)^2)
                
                # Pick the closest n_ij points
                n_to_take = min(n_ij, length(cell_pts))
                for k in 1:n_to_take
                    push!(pts, cell_pts[k])
                end
            end
        end
        return pts
    else
        # Manual or random mode (default coordinate extraction)
        pts = Point2D[]
        for (x, y) in config.coords
            push!(pts, Point2D(x, y))
        end
        return pts
    end
end

"""
    expand_coordinates(config::TSVConfig) -> Vector{Point2D}

Fallback / legacy single-argument coordinate expansion method.
"""
function expand_coordinates(config::TSVConfig)
    return expand_coordinates(config, 1.2e-3, 1.2e-3)
end

"""
    get_cell_capacities(config::TSVConfig, lx::Float64, ly::Float64) -> Matrix{Int}

Get cell capacities grid based on physical spacing and guard configurations.
"""
function get_cell_capacities(config::TSVConfig, lx::Float64, ly::Float64)
    if config.density === nothing || config.manufacturing === nothing
        return fill(0, 0, 0)
    end
    
    gx = config.density.gx
    gy = config.density.gy
    p_min = config.manufacturing.p_min
    
    n_max_matrix = Matrix{Int}(undef, gx, gy)
    g = p_min / 2.0
    
    for j in 1:gy
        for i in 1:gx
            x_min = (i - 1) * (lx / gx)
            x_max = i * (lx / gx)
            y_min = (j - 1) * (ly / gy)
            y_max = j * (ly / gy)
            
            Nx = floor(Int, (x_max - x_min - 2.0 * g) / p_min) + 1
            Ny = floor(Int, (y_max - y_min - 2.0 * g) / p_min) + 1
            
            if Nx <= 0 || Ny <= 0
                n_max_matrix[i, j] = 0
            else
                n_max_matrix[i, j] = Nx * Ny
            end
        end
    end
    return n_max_matrix
end

"""
    get_cell_capacities(config::TSVConfig) -> Matrix{Int}

Fallback / legacy cell capacities matrix retriever.
"""
function get_cell_capacities(config::TSVConfig)
    return get_cell_capacities(config, 1.2e-3, 1.2e-3)
end

"""
    adjust_density_constraints(mu::Vector{Float64}, n_max_matrix::Matrix{Int}, N_limit::Int) -> Vector{Float64}

Scale density matrix constraints using bisection search to guarantee physical feasibility limits.
"""
function adjust_density_constraints(mu::Vector{Float64}, n_max_matrix::Matrix{Int}, N_limit::Int)
    n_max_flat = vec(n_max_matrix)
    @assert length(mu) == length(n_max_flat) "Dimension mismatch between mu and n_max_matrix (mu: $(length(mu)), matrix: $(length(n_max_flat)))"
    
    # Calculate current raw count
    sum_n = sum(round(Int, mu[k] * n_max_flat[k]) for k in eachindex(mu))
    if sum_n <= N_limit
        return copy(mu)
    end
    
    # Bisection search to find the optimal scale factor s in [0.0, 1.0]
    low = 0.0
    high = 1.0
    best_s = 0.0
    for iter in 1:60
        mid = (low + high) / 2.0
        s_mu = mid .* mu
        sum_scaled = sum(round(Int, s_mu[k] * n_max_flat[k]) for k in eachindex(mu))
        if sum_scaled <= N_limit
            best_s = mid
            low = mid
        else
            high = mid
        end
    end
    
    return best_s .* mu
end

end # module
