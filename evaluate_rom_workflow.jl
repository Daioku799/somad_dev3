using JLD2
using JSON3
using Printf
using LinearAlgebra

# 1. Loading core modules (at global scope)
println(">>> 1. Loading core modules...")
push!(LOAD_PATH, abspath("H2-main-ext/src"))
include(joinpath(abspath("H2-main-ext/src"), "modelA.jl"))
using .modelA

if !isdefined(Main, :PODEngine)
    include(abspath("H2-rom/src/PODEngine/PODEngine.jl"))
end
using .PODEngine

if !isdefined(Main, :ROMInterpolator)
    include(abspath("H2-rom/src/ROMInterpolator/ROMInterpolator.jl"))
end
using .ROMInterpolator

if !isdefined(Main, :ROMValidator)
    include(abspath("H2-rom/src/ROMValidator/ROMValidator.jl"))
end
using .ROMValidator

function evaluate_rom()
    println(">>> 2. Parsing manifest.json...")
    manifest_path = "data/manifest.json"
    if !isfile(manifest_path)
        error("manifest.json not found. Run generate_snapshots.jl first!")
    end

    # Load manifest
    manifest_content = JSON3.read(read(manifest_path, String))
    cases = manifest_content.cases

    # Filter successful cases
    success_cases = filter(c -> c.status == "success", cases)
    println("Total successful cases in manifest: ", length(success_cases))

    if length(success_cases) < 3
        error("Too few successful cases. Run generate_snapshots.jl first or wait until it generates more cases!")
    end

    # We will use 80% of cases for training and 20% for validation
    n_total = length(success_cases)
    n_train = round(Int, n_total * 0.8)
    n_val = n_total - n_train
    println("Split: Training cases = $n_train, Validation cases = $n_val")

    train_cases = success_cases[1:n_train]
    val_cases = success_cases[(n_train+1):end]

    trained_snapshot_ids = String[string(c.id) for c in train_cases]

    # Load training snapshots to construct data matrix
    println(">>> 3. Loading training snapshots...")
    temp_fields = Vector{Float64}[]
    mu_list = Vector{Float64}[]

    # To load grid info from the first snapshot
    grid_info = Dict{String, Any}()
    z_centers = Float64[]
    z_faces = Float64[]
    nx, ny, nz = 0, 0, 0
    lx, ly = 1.2e-3, 1.2e-3

    for (idx, c) in enumerate(train_cases)
        filepath = c.filepath
        if !isfile(filepath) && startswith(filepath, "../data/")
            filepath = replace(filepath, "../data/" => "data/")
        end
        if !isfile(filepath)
            error("Snapshot file not found: $filepath")
        end
        
        # Read snapshot data
        jld = jldopen(filepath, "r")
        temp = jld["temperature"]
        meta = jld["metadata"]
        
        if idx == 1
            nx = jld["nx"]
            ny = jld["ny"]
            nz = jld["nz"]
            z_centers = vec(jld["z_centers"])
            z_faces = vec(jld["z_faces"])
            
            # lx, ly from config summary if available, else fallback
            lx = 1.2e-3
            ly = 1.2e-3
            grid_info = Dict{String, Any}(
                "nx" => nx,
                "ny" => ny,
                "nz" => nz,
                "lx" => lx,
                "ly" => ly,
                "z_centers" => z_centers
            )
        end
        
        push!(temp_fields, vec(temp))
        push!(mu_list, vec(meta["mu"]))
        close(jld)
    end

    X_snap = reduce(hcat, temp_fields)
    Mu = reduce(hcat, mu_list)

    # 4. Perform POD Decomposition
    println(">>> 4. Performing POD Decomposition...")
    ric_threshold = 0.999 # Keep high RIC
    basis, singular_values, coeffs, mean_field = PODEngine.compute_pod(X_snap; ric_threshold=ric_threshold)
    println("  -> Singular values count: ", length(singular_values))
    println("  -> Selected POD modes count: ", size(basis, 2))

    # 5. Train ROM Model
    println(">>> 5. Training ROM Model...")
    rom_model_dir = "data/models"
    mkpath(rom_model_dir)
    rom_model_path = joinpath(rom_model_dir, "trained_rom_model.jld2")

    # Train RBF
    t_start_build = time_ns()
    rom_model = ROMInterpolator.train_rom(Mu, coeffs, rom_model_path; epsilon=1.0, lambda=1e-6)
    rom_build_time = (time_ns() - t_start_build) / 1e9
    println("  -> ROM Model saved to: ", rom_model_path)
    @printf("  -> ROM Build Time: %.3f seconds\n", rom_build_time)

    # 6. Run ROM Validation
    println(">>> 6. Running ROM Validation...")
    output_dir = "plots/validation"
    mkpath(output_dir)

    summary = ROMValidator.run_validation(
        rom_model_path,
        "data/raw",
        output_dir,
        trained_snapshot_ids,
        grid_info,
        basis,
        mean_field;
        tmax_threshold=2.0,
        rom_build_time=rom_build_time,
        save_individuals=false,
        normalize_plots=false
    )

    println("\n" * "="^50)
    println("             ROM VALIDATION SUMMARY")
    println("="^50)
    println("Overall Status: ", summary.overall_status)
    println("Total Validation Samples: ", length(summary.results))
    println("Mean L2 Relative Error:   ", summary.mean_metrics["relative_l2_error"])
    println("Max L2 Relative Error:    ", summary.max_metrics["relative_l2_error"])
    println("Mean Tmax Absolute Error: ", summary.mean_metrics["tmax_error"], " [K]")
    println("Max Tmax Absolute Error:  ", summary.max_metrics["tmax_error"], " [K]")
    println("Mean Hotspot Dist Error:  ", summary.mean_metrics["hotspot_dist"], " [m]")
    println("Max Hotspot Dist Error:   ", summary.max_metrics["hotspot_dist"], " [m]")
    println("="^50)
    println("Check generated validation report:")
    println("  -> plots/validation/validation.md")
    println("  -> plots/validation/validation.json")
    println("="^50)
end

evaluate_rom()
