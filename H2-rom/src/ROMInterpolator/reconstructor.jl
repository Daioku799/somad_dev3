"""
    reconstruct_field(coeffs::Vector{Float64}, basis::Matrix{Float64}, mean_field::Vector{Float64}) -> Vector{Float64}

Reconstruct the temperature field from POD coefficients and basis, plus the mean field.
Formulation: θ = mean_field + basis * coeffs

Throws `DimensionMismatch` if the sizes of basis, coeffs, and mean_field do not match.
"""
function reconstruct_field(coeffs::Vector{Float64}, basis::Matrix{Float64}, mean_field::Vector{Float64})
    if size(basis, 2) != length(coeffs)
        throw(DimensionMismatch("The number of columns in basis ($(size(basis, 2))) must match the number of coefficients ($(length(coeffs)))."))
    end
    if size(basis, 1) != length(mean_field)
        throw(DimensionMismatch("The number of rows in basis ($(size(basis, 1))) must match the length of the mean field ($(length(mean_field)))."))
    end
    return mean_field + basis * coeffs
end

"""
    reshape_to_3d(theta::Vector{Float64}, grid_size::Tuple{Int, Int, Int}) -> Array{Float64, 3}

Reshape a flat temperature field vector `theta` into a 3D grid of size `grid_size`.

Throws `DimensionMismatch` if the product of `grid_size` does not match the length of `theta`.
"""
function reshape_to_3d(theta::Vector{Float64}, grid_size::Tuple{Int, Int, Int})
    if prod(grid_size) != length(theta)
        throw(DimensionMismatch("The grid size product ($(prod(grid_size))) must match the vector length ($(length(theta)))."))
    end
    return reshape(theta, grid_size)
end

"""
    get_tmax(theta::AbstractVector{Float64}) -> Float64

Extract the maximum temperature from the temperature field vector `theta`.

Throws `ArgumentError` if `theta` is empty.
"""
function get_tmax(theta::AbstractVector{Float64})
    if isempty(theta)
        throw(ArgumentError("The temperature field vector cannot be empty."))
    end
    return maximum(theta)
end

