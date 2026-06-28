"""
    PODModel

Proper Orthogonal Decomposition (POD) model structure.

# Fields
- `basis::Matrix{Float64}`: POD Modes Ur (size N_grid x r)
- `singular_values::Vector{Float64}`: Singular values Sigma_r (size r)
- `coefficients::Matrix{Float64}`: Modal coefficients A (size r x N_snapshots)
- `mean_field::Vector{Float64}`: Mean temperature field bar_theta (size N_grid)
- `snapshot_ids::Vector{String}`: IDs of snapshots used in training (size N_snapshots)
- `mu_vectors::Matrix{Float64}`: Parameter vectors mu (size G_total x N_snapshots)
- `metadata::Dict{String, Any}`: Metadata such as `ric_threshold`, `n_modes`, `trained_snapshot_ids`, and grid details
"""
struct PODModel
    basis::Matrix{Float64}
    singular_values::Vector{Float64}
    coefficients::Matrix{Float64}
    mean_field::Vector{Float64}
    snapshot_ids::Vector{String}
    mu_vectors::Matrix{Float64}
    metadata::Dict{String, Any}
end
