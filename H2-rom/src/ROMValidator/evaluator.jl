using JLD2

"""
    get_validation_samples(raw_dir::String, trained_snapshot_ids::Vector{String}) -> Vector{String}

Search for `.jld2` files inside `raw_dir`. Load `metadata` from each file, extract `snapshot_id`
(from `metadata["snapshot_id"]`), and check if it is NOT in `trained_snapshot_ids`.
Return the list of file paths for these unlearned snapshots.
"""
function get_validation_samples(raw_dir::String, trained_snapshot_ids::Vector{String})::Vector{String}
    validation_samples = String[]
    if !isdir(raw_dir)
        return validation_samples
    end
    
    for file in readdir(raw_dir; join=true)
        if isfile(file) && endswith(file, ".jld2")
            try
                JLD2.jldopen(file, "r") do jld
                    if haskey(jld, "metadata")
                        meta = jld["metadata"]
                        if haskey(meta, "snapshot_id")
                            snapshot_id = meta["snapshot_id"]
                            if !(snapshot_id in trained_snapshot_ids)
                                push!(validation_samples, file)
                            end
                        end
                    end
                end
            catch e
                @warn "Failed to read JLD2 file: $file" exception=e
            end
        end
    end
    return validation_samples
end

"""
    load_test_case(filepath::String) -> Tuple{Vector{Float64}, Vector{Float64}, String}

Load `temperature` and `metadata` from the specified JLD2 file. Flat-map `temperature`
using `vec` if it is a 3D array (or vector). Return `(temperature_vector, mu_vector, snapshot_id)`.
"""
function load_test_case(filepath::String)::Tuple{Vector{Float64}, Vector{Float64}, String}
    local temp, meta
    JLD2.jldopen(filepath, "r") do jld
        temp = jld["temperature"]
        meta = jld["metadata"]
    end
    
    temp_vec = vec(temp)
    temp_vec_float = convert(Vector{Float64}, temp_vec)
    
    mu_vec = meta["mu"]
    mu_vec_float = convert(Vector{Float64}, vec(mu_vec))
    
    snapshot_id = string(meta["snapshot_id"])
    
    return (temp_vec_float, mu_vec_float, snapshot_id)
end

"""
    calculate_l2_error(theta_fvm::Vector{Float64}, theta_rom::Vector{Float64}) -> Float64

Calculate the relative L2 error between FVM temperature and ROM predicted temperature.
Throws `DimensionMismatch` if the lengths of the two vectors do not match.
Returns `0.0` if the L2 norm of `theta_fvm` is less than `1e-12` to avoid zero division.
"""
function calculate_l2_error(theta_fvm::Vector{Float64}, theta_rom::Vector{Float64})::Float64
    if length(theta_fvm) != length(theta_rom)
        throw(DimensionMismatch("Vectors must have the same length (FVM: $(length(theta_fvm)), ROM: $(length(theta_rom)))"))
    end
    norm_fvm = norm(theta_fvm)
    if norm_fvm < 1e-12
        return 0.0
    end
    return norm(theta_fvm - theta_rom) / norm_fvm
end

"""
    calculate_tmax_error(theta_fvm::Vector{Float64}, theta_rom::Vector{Float64}) -> Float64

Calculate the absolute maximum temperature difference between FVM and ROM temperatures.
Throws `ArgumentError` if either vector is empty.
Throws `DimensionMismatch` if the lengths of the two vectors do not match.
"""
function calculate_tmax_error(theta_fvm::Vector{Float64}, theta_rom::Vector{Float64})::Float64
    if length(theta_fvm) == 0
        throw(ArgumentError("Vectors must not be empty"))
    end
    if length(theta_fvm) != length(theta_rom)
        throw(DimensionMismatch("Vectors must have the same length (FVM: $(length(theta_fvm)), ROM: $(length(theta_rom)))"))
    end
    return abs(maximum(theta_fvm) - maximum(theta_rom))
end

