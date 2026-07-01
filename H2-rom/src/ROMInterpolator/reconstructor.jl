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
