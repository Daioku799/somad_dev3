module Layout

using ..Types: Point2D
using ...ConfigLoader: TSVConfig

export expand_coordinates, get_cell_capacities, adjust_density_constraints

"""
    expand_coordinates(config::TSVConfig) -> Vector{Point2D}

Expand coordinates list based on configuration. Stub for now.
"""
function expand_coordinates(config::TSVConfig)
    pts = Point2D[]
    for (x, y) in config.coords
        push!(pts, Point2D(x, y))
    end
    return pts
end

"""
    get_cell_capacities(config::TSVConfig) -> Matrix{Int}

Get cell capacities grid. Stub for now.
"""
function get_cell_capacities(config::TSVConfig)
    gx = (config.density !== nothing) ? config.density.gx : 4
    gy = (config.density !== nothing) ? config.density.gy : 4
    return fill(10, gx, gy)
end

"""
    adjust_density_constraints(mu::Vector{Float64}, n_max_matrix::Matrix{Int}, N_limit::Int) -> Vector{Float64}

Scale density matrix constraints. Stub for now.
"""
function adjust_density_constraints(mu::Vector{Float64}, n_max_matrix::Matrix{Int}, N_limit::Int)
    return copy(mu)
end

end # module
