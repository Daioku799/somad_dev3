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

using JLD2

"""
    save_pod_model(filepath::String, model::PODModel)

Save a `PODModel` to a JLD2 file.
"""
function save_pod_model(filepath::String, model::PODModel)
    JLD2.jldopen(filepath, "w") do file
        file["model"] = model
    end
end

"""
    load_pod_model(filepath::String) -> PODModel

Load a `PODModel` from a JLD2 file.
"""
function load_pod_model(filepath::String)
    model = JLD2.jldopen(filepath, "r") do file
        if !haskey(file, "model")
            error("JLD2 file does not contain a 'model' field")
        end
        return file["model"]::PODModel
    end
    return model
end

"""
    run_pod_generation(raw_dir::String, model_path::String; ric_threshold::Float64=0.999)

Orchestrate the POD generation pipeline:
1. Loads the snapshot matrix, snapshot IDs, and parameter vectors from `raw_dir`.
2. Performs SVD and calculates/truncates the POD basis, singular values, coefficients, and mean field.
3. Construct metadata including `trained_snapshot_ids` and `grid` information.
4. Saves the compiled `PODModel` to `model_path`.
"""
function run_pod_generation(raw_dir::String, model_path::String; ric_threshold::Float64=0.999)
    # 1. Load data
    X, snapshot_ids, mu_vectors, grid_info = load_snapshot_matrix(raw_dir)
    
    # 2. Compute POD
    basis, singular_values, coefficients, mean_field = compute_pod(X; ric_threshold=ric_threshold)
    
    # 3. Construct metadata
    nx, ny, nz = grid_info["nx"], grid_info["ny"], grid_info["nz"]
    dims = (nx, ny, nz)
    
    dx = get(grid_info, "dx", 0.1)
    dy = get(grid_info, "dy", 0.1)
    dz = 0.1
    if haskey(grid_info, "z_centers") && length(grid_info["z_centers"]) > 1
        dz = grid_info["z_centers"][2] - grid_info["z_centers"][1]
    end
    spacing = get(grid_info, "spacing", (dx, dy, dz))
    
    lx = get(grid_info, "lx", nx * spacing[1])
    ly = get(grid_info, "ly", ny * spacing[2])
    lz = get(grid_info, "lz", nz * spacing[3])
    physical_size = get(grid_info, "physical_size", (lx, ly, lz))
    
    grid = Dict{String, Any}(
        "dims" => dims,
        "spacing" => spacing,
        "physical_size" => physical_size
    )
    if haskey(grid_info, "z_centers")
        grid["z_centers"] = grid_info["z_centers"]
    end
    if haskey(grid_info, "z_faces")
        grid["z_faces"] = grid_info["z_faces"]
    end
    
    metadata = Dict{String, Any}(
        "ric_threshold" => ric_threshold,
        "n_modes" => length(singular_values),
        "trained_snapshot_ids" => snapshot_ids,
        "grid" => grid
    )
    
    # 4. Construct and save model
    model = PODModel(
        basis,
        singular_values,
        coefficients,
        mean_field,
        snapshot_ids,
        mu_vectors,
        metadata
    )
    
    # Create parent directory if it doesn't exist
    model_dir = dirname(model_path)
    if !isempty(model_dir) && !isdir(model_dir)
        mkpath(model_dir)
    end
    
    save_pod_model(model_path, model)
end

