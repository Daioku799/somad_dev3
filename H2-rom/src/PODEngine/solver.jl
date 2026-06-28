using LinearAlgebra
using Statistics

"""
    compute_pod(X::AbstractMatrix; ric_threshold::Float64=0.999)

Compute the Proper Orthogonal Decomposition (POD) of snapshot matrix `X`.
Returns `(Ur, Sr, Vr_coeffs, mean_field)`.
"""
function compute_pod(X::AbstractMatrix; ric_threshold::Float64=0.999)
    # Calculate row-wise mean field
    mean_field = vec(mean(X, dims=2))
    
    # Center the snapshots (subtract mean field from each column)
    X_centered = X .- mean_field
    
    # Perform Singular Value Decomposition
    F = svd(X_centered)
    
    # Determine the number of modes based on Cumulative Energy (RIC)
    s_sq = F.S .^ 2
    total_variance = sum(s_sq)
    
    if total_variance ≈ 0.0
        r = 1
    else
        cum_variance = cumsum(s_sq)
        ric = cum_variance ./ total_variance
        r = findfirst(val -> val >= ric_threshold, ric)
        if r === nothing
            r = length(F.S)
        end
    end
    
    # Truncate U and S
    Ur = F.U[:, 1:r]
    Sr = F.S[1:r]
    
    # Compute projection coefficients A = Ur' * X_centered
    Vr_coeffs = Ur' * X_centered
    
    return Ur, Sr, Vr_coeffs, mean_field
end
