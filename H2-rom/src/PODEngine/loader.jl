using JLD2

"""
    load_snapshot_matrix(dir_path::String)

Scan the directory `dir_path` for `.jld2` snapshot files.
For each snapshot JLD2:
- Extract `"temperature"` field (3D matrix or vector) and flatten it into a 1D column vector.
- Extract `"metadata"` containing `"snapshot_id"` and `"mu"`.
- Extract `"nx"`, `"ny"`, `"nz"` fields (to verify grid metadata) and optionally `"z_centers"` or other spacing data if available.

Construct the snapshot matrix \$X\$ (rows = elements, columns = snapshots).
Collect `snapshot_ids` (vector of String) and `mu_vectors` (Matrix where each column is the parameter vector `mu` for a snapshot).

Return `(X, snapshot_ids, mu_vectors, grid_info::Dict)`.
"""
function load_snapshot_matrix(dir_path::String)
    # Scan directory for .jld2 files
    files = filter(f -> endswith(f, ".jld2"), readdir(dir_path; join=true))
    sort!(files)
    
    if isempty(files)
        error("No snapshot files found in directory: \$dir_path")
    end
    
    snapshot_ids = String[]
    mu_list = Vector{Float64}[]
    X_cols = Vector{Float64}[]
    
    grid_info = Dict{String, Any}()
    
    for (i, filepath) in enumerate(files)
        JLD2.jldopen(filepath, "r") do file
            # temperature
            if !haskey(file, "temperature")
                error("File \$filepath does not contain 'temperature' field")
            end
            temp = file["temperature"]
            push!(X_cols, vec(temp))
            
            # metadata
            if !haskey(file, "metadata")
                error("File \$filepath does not contain 'metadata' field")
            end
            meta = file["metadata"]
            if !haskey(meta, "snapshot_id") || !haskey(meta, "mu")
                error("Metadata in \$filepath must contain 'snapshot_id' and 'mu'")
            end
            push!(snapshot_ids, string(meta["snapshot_id"]))
            push!(mu_list, Float64.(meta["mu"]))
            
            # grid metadata for verification
            nx = file["nx"]
            ny = file["ny"]
            nz = file["nz"]
            
            # optionally spacing or other data
            z_centers = haskey(file, "z_centers") ? file["z_centers"] : nothing
            z_faces = haskey(file, "z_faces") ? file["z_faces"] : nothing
            
            if i == 1
                grid_info["nx"] = nx
                grid_info["ny"] = ny
                grid_info["nz"] = nz
                if !isnothing(z_centers)
                    grid_info["z_centers"] = z_centers
                end
                if !isnothing(z_faces)
                    grid_info["z_faces"] = z_faces
                end
            else
                if grid_info["nx"] != nx || grid_info["ny"] != ny || grid_info["nz"] != nz
                    error("Grid size inconsistency detected. First file: (nx=$(grid_info["nx"]), ny=$(grid_info["ny"]), nz=$(grid_info["nz"])). Current file $filepath: (nx=$nx, ny=$ny, nz=$nz)")
                end
            end
        end
    end
    
    # Construct the snapshot matrix X
    X = hcat(X_cols...)
    
    # Collect mu_vectors
    mu_vectors = hcat(mu_list...)
    
    return X, snapshot_ids, mu_vectors, grid_info
end
