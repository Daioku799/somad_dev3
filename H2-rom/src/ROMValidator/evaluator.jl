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
    get_trained_samples(raw_dir::String, trained_snapshot_ids::Vector{String}) -> Vector{String}

Search for `.jld2` files inside `raw_dir`. Load `metadata` from each file, extract `snapshot_id`
(from `metadata["snapshot_id"]`), and check if it is IN `trained_snapshot_ids`.
Return the list of file paths for these trained snapshots.
"""
function get_trained_samples(raw_dir::String, trained_snapshot_ids::Vector{String})::Vector{String}
    trained_samples = String[]
    if !isdir(raw_dir)
        return trained_samples
    end
    
    for file in readdir(raw_dir; join=true)
        if isfile(file) && endswith(file, ".jld2")
            try
                JLD2.jldopen(file, "r") do jld
                    if haskey(jld, "metadata")
                        meta = jld["metadata"]
                        if haskey(meta, "snapshot_id")
                            snapshot_id = meta["snapshot_id"]
                            if snapshot_id in trained_snapshot_ids
                                push!(trained_samples, file)
                            end
                        end
                    end
                end
            catch e
                @warn "Failed to read JLD2 file: $file" exception=e
            end
        end
    end
    return trained_samples
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

"""
    calculate_hotspot_error(theta_fvm::Vector{Float64}, theta_rom::Vector{Float64}, grid_info::Dict{String, Any}) -> Float64

Calculate the geometric Euclidean distance between the hot spots of the FVM and ROM temperatures.
Throws `DimensionMismatch` if the lengths of the two vectors do not match or if they do not match the grid configuration.
Throws `KeyError` if any of the required keys (`nx`, `ny`, `nz`, `lx`, `ly`, `z_centers`) are missing from `grid_info`.
"""
function calculate_hotspot_error(
    theta_fvm::Vector{Float64}, 
    theta_rom::Vector{Float64}, 
    grid_info::Dict{String, Any}
)::Float64
    # 1. Input validation
    if length(theta_fvm) != length(theta_rom)
        throw(DimensionMismatch("FVM vector length ($(length(theta_fvm))) does not match ROM vector length ($(length(theta_rom)))"))
    end
 
    # Check required keys in grid_info
    required_keys = ["nx", "ny", "nz", "lx", "ly", "z_centers"]
    for key in required_keys
        if !haskey(grid_info, key)
            throw(KeyError(key))
        end
    end
 
    nx = grid_info["nx"]
    ny = grid_info["ny"]
    nz = grid_info["nz"]
    lx = grid_info["lx"]
    ly = grid_info["ly"]
    z_centers = grid_info["z_centers"]
 
    # Determine grid format (ghost cells included or not)
    grid_total = nx * ny * nz
    mz = length(z_centers)
    ghost_grid_total = (nx + 2) * (ny + 2) * mz
    
    use_ghost = false
    if length(theta_fvm) == ghost_grid_total
        use_ghost = true
    elseif length(theta_fvm) != grid_total
        throw(DimensionMismatch("Vector length ($(length(theta_fvm))) does not match grid configuration dimensions (regular: $(grid_total), ghost: $(ghost_grid_total))"))
    end
 
    # 2. Argmax calculation
    idx_fvm = argmax(theta_fvm)
    idx_rom = argmax(theta_rom)
 
    # Helper function to convert 1D index (Column-major) to physical coordinates (x, y, z)
    function idx_to_coords(idx::Int)::Tuple{Float64, Float64, Float64}
        if use_ghost
            mx = nx + 2
            my = ny + 2
            k = div(idx - 1, mx * my) + 1
            r = mod(idx - 1, mx * my)
            j = div(r, mx) + 1
            i = mod(r, mx) + 1
            
            dx = lx / nx
            dy = ly / ny
            x = (i - 1.5) * dx
            y = (j - 1.5) * dy
            z = z_centers[k]
        else
            k = div(idx - 1, nx * ny) + 1
            r = mod(idx - 1, nx * ny)
            j = div(r, nx) + 1
            i = mod(r, nx) + 1
     
            dx = lx / nx
            dy = ly / ny
            x = (i - 0.5) * dx
            y = (j - 0.5) * dy
            z = z_centers[k]
        end
        return (x, y, z)
    end
 
    x_fvm, y_fvm, z_fvm = idx_to_coords(idx_fvm)
    x_rom, y_rom, z_rom = idx_to_coords(idx_rom)
 
    # 3. Calculate Euclidean distance
    dist = sqrt((x_fvm - x_rom)^2 + (y_fvm - y_rom)^2 + (z_fvm - z_rom)^2)
    return dist
end

"""
    judge_accuracy(mean_tmax_error::Float64; tmax_threshold::Float64=2.0) -> Symbol

Judge whether the model accuracy is acceptable based on the mean Tmax error.
Returns `:validated` if the error is within the threshold, or `:unfit` otherwise.
"""
function judge_accuracy(mean_tmax_error::Float64; tmax_threshold::Float64=2.0)::Symbol
    if mean_tmax_error <= tmax_threshold
        return :validated
    else
        return :unfit
    end
end

"""
    evaluate_validation_results(results::Vector{ValidationResult}; tmax_threshold::Float64=2.0) -> ValidationSummary

Aggregate validation results from multiple samples to calculate mean and max error metrics,
and determine the overall validation status.
Throws `ArgumentError` if the input vector is empty.
"""
function evaluate_validation_results(
    results::Vector{ValidationResult}; 
    tmax_threshold::Float64=2.0
)::ValidationSummary
    if length(results) == 0
        throw(ArgumentError("Validation results vector must not be empty"))
    end
 
    n_samples = length(results)
    
    sum_l2 = 0.0
    sum_tmax = 0.0
    sum_hotspot = 0.0
    
    max_l2 = -Inf
    max_tmax = -Inf
    max_hotspot = -Inf
    
    for r in results
        sum_l2 += r.relative_l2_error
        sum_tmax += r.tmax_error
        sum_hotspot += r.hotspot_dist
        
        max_l2 = max(max_l2, r.relative_l2_error)
        max_tmax = max(max_tmax, r.tmax_error)
        max_hotspot = max(max_hotspot, r.hotspot_dist)
    end
    
    mean_l2 = sum_l2 / n_samples
    mean_tmax = sum_tmax / n_samples
    mean_hotspot = sum_hotspot / n_samples
    
    mean_metrics = Dict{String, Float64}(
        "relative_l2_error" => mean_l2,
        "tmax_error" => mean_tmax,
        "hotspot_dist" => mean_hotspot
    )
    
    max_metrics = Dict{String, Float64}(
        "relative_l2_error" => max_l2,
        "tmax_error" => max_tmax,
        "hotspot_dist" => max_hotspot
    )
    
    overall_status = judge_accuracy(mean_tmax; tmax_threshold=tmax_threshold)
    
    return ValidationSummary(results, mean_metrics, max_metrics, overall_status)
end

"""
    run_validation(
        model_path::String,
        snapshot_dir::String,
        output_dir::String,
        trained_snapshot_ids::Vector{String},
        grid_info::Dict{String, Any},
        basis::Matrix{Float64},
        mean_field::Vector{Float64};
        tmax_threshold::Float64=2.0
    ) -> ValidationSummary

Orchestrate the validation process for the ROM model: select validation data, evaluate ROM predictions,
calculate error metrics, judge accuracy, and generate slice comparison plots and a summary report.
"""
function run_validation(
    model_path::String,
    snapshot_dir::String,
    output_dir::String,
    trained_snapshot_ids::Vector{String},
    grid_info::Dict{String, Any},
    basis::Matrix{Float64},
    mean_field::Vector{Float64};
    tmax_threshold::Float64=2.0,
    self_reproduce_threshold::Float64=0.5,
    save_individuals::Bool=false,
    normalize_plots::Bool=false
)::ValidationSummary
    # 1. Identify validation sample files
    sample_files = get_validation_samples(snapshot_dir, trained_snapshot_ids)
    if isempty(sample_files)
        throw(ArgumentError("No validation samples found in $snapshot_dir"))
    end

    # 2. Load model
    model = ROMInterpolator.load_rom_model(model_path)

    results = ValidationResult[]

    # 3. Evaluate each sample
    for file in sample_files
        theta_fvm, mu, snapshot_id = load_test_case(file)
        
        # ROM prediction and reconstruction
        theta_rom = ROMInterpolator.evaluate_rom(model, basis, mean_field, mu)
        
        # Calculate error metrics
        l2_err = calculate_l2_error(theta_fvm, theta_rom)
        tmax_err = calculate_tmax_error(theta_fvm, theta_rom)
        hotspot_err = calculate_hotspot_error(theta_fvm, theta_rom, grid_info)
        
        is_passed = tmax_err <= tmax_threshold
        
        push!(results, ValidationResult(snapshot_id, l2_err, tmax_err, hotspot_err, is_passed))
        
        # Generate slice comparison plots
        generate_comparison_plots(
            theta_fvm, theta_rom, grid_info, output_dir, snapshot_id, mu;
            save_individuals=save_individuals, normalize=normalize_plots
        )
    end

    # 4. Evaluate self-reproduction error on trained snapshots
    self_l2_errors = Float64[]
    self_tmax_errors = Float64[]
    trained_files = get_trained_samples(snapshot_dir, trained_snapshot_ids)
    
    for file in trained_files
        theta_fvm, mu, snapshot_id = load_test_case(file)
        theta_rom = ROMInterpolator.evaluate_rom(model, basis, mean_field, mu)
        
        l2_err = calculate_l2_error(theta_fvm, theta_rom)
        tmax_err = calculate_tmax_error(theta_fvm, theta_rom)
        
        push!(self_l2_errors, l2_err)
        push!(self_tmax_errors, tmax_err)
    end
    
    mean_self_l2 = isempty(self_l2_errors) ? 0.0 : sum(self_l2_errors) / length(self_l2_errors)
    max_self_l2 = isempty(self_l2_errors) ? 0.0 : maximum(self_l2_errors)
    mean_self_tmax = isempty(self_tmax_errors) ? 0.0 : sum(self_tmax_errors) / length(self_tmax_errors)
    max_self_tmax = isempty(self_tmax_errors) ? 0.0 : maximum(self_tmax_errors)
    
    is_warning = max_self_tmax > self_reproduce_threshold
    
    self_reproduction_metrics = Dict{String, Any}(
        "mean_l2_error" => mean_self_l2,
        "max_l2_error" => max_self_l2,
        "mean_tmax_error" => mean_self_tmax,
        "max_tmax_error" => max_self_tmax,
        "is_warning" => is_warning
    )

    # 5. Generate ValidationSummary
    base_summary = evaluate_validation_results(results; tmax_threshold=tmax_threshold)
    
    overall_status = base_summary.overall_status
    if overall_status == :validated && is_warning
        overall_status = :warning
    end
    
    summary = ValidationSummary(
        base_summary.results,
        base_summary.mean_metrics,
        base_summary.max_metrics,
        overall_status,
        Dict{String, Any}(), # Performance metrics will be implemented in Task 7.4
        self_reproduction_metrics
    )

    # 6. Generate Markdown and JSON reports
    generate_report(summary, output_dir)

    return summary
end

"""
    measure_dataset_size(snapshot_dir::String) -> Int64

Calculate the total file size (in bytes) of all `.jld2` snapshot files in `snapshot_dir`.
If the directory does not exist, return 0.
"""
function measure_dataset_size(snapshot_dir::String)::Int64
    if !isdir(snapshot_dir)
        return 0
    end
    total_size = 0
    for file in readdir(snapshot_dir; join=true)
        if isfile(file) && endswith(file, ".jld2")
            total_size += filesize(file)
        end
    end
    return total_size
end

"""
    measure_fvm_runtime(manifest_path::String) -> Tuple{Float64, Float64}

Calculate the total and average runtime (in seconds) of successful FVM cases from `manifest.json`.
Returns `(total_runtime, average_runtime)`.
If the manifest file does not exist, return `(0.0, 0.0)`.
If there are no successful cases, return `(0.0, 0.0)`.
"""
function measure_fvm_runtime(manifest_path::String)::Tuple{Float64, Float64}
    if !isfile(manifest_path)
        @warn "Manifest file not found: $manifest_path"
        return (0.0, 0.0)
    end
    
    try
        content = read(manifest_path, String)
        manifest = JSON3.read(content, Dict{String, Any})
        
        total_runtime = 0.0
        success_count = 0
        
        if haskey(manifest, "cases")
            for case_obj in manifest["cases"]
                status = get(case_obj, "status", "")
                if status == "success"
                    runtime = Float64(get(case_obj, "runtime", 0.0))
                    total_runtime += runtime
                    success_count += 1
                end
            end
        end
        
        avg_runtime = success_count > 0 ? total_runtime / success_count : 0.0
        return (total_runtime, avg_runtime)
    catch e
        @error "Failed to parse manifest file: $manifest_path" exception=e
        return (0.0, 0.0)
    end
end


