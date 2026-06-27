module SnapshotGenerator

include("Types.jl")
include("Manifest.jl")
include("Sampler.jl")
include("Runner.jl")

using .Types
using .Manifest: save_manifest, load_manifest, add_case!, update_case_status!
using .Sampler
using .Runner
using Dates

export run_generator, SnapshotManifest, SnapshotCase

"""
    run_generator(n_cases::Int; solver_dir="../H2-main-ext", data_dir="../data")

Main entry point for generating snapshots.
"""
function run_generator(n_cases::Int; solver_dir="../H2-main-ext", data_dir="../data")
    manifest_path = joinpath(data_dir, "manifest.json")
    raw_dir = joinpath(data_dir, "raw")
    work_dir = joinpath(data_dir, "work")
    
    mkpath(raw_dir)
    mkpath(work_dir)
    
    # Load baseline configurations from solver directory
    config_path = joinpath(solver_dir, "config.json")
    tsv_config_path = joinpath(solver_dir, "tsv_config.json")
    baseline_config = Sampler.H2MainExt.ConfigLoader.load_config(config_path, tsv_config_path)
    
    # 1. Load/Initialize Manifest
    manifest = load_manifest(manifest_path)
    println("Manifest loaded. Current cases: ", length(manifest.cases))
    
    # 2. Generate new samples
    println("Generating $n_cases new samples using LHS...")
    grid_size = (baseline_config.tsv.density.gx, baseline_config.tsv.density.gy)
    n_limit = baseline_config.tsv.density.n_max
    
    new_params = generate_samples(n_cases, grid_size; n_limit=n_limit, include_representative=true)
    
    # 3. Add cases to manifest
    pending_ids = Int[]
    for mu in new_params
        c = add_case!(manifest, mu)
        push!(pending_ids, c.id)
    end
    save_manifest(manifest, manifest_path)
    
    # 4. Run loop
    println("Starting batch execution of ", length(pending_ids), " cases...")
    
    success_count = 0
    failed_count = 0
    timeout_count = 0
    
    for id in pending_ids
        case = filter(c -> c.id == id, manifest.cases)[1]
        
        status, snap_path, err = run_simulation_case(
            case,
            solver_dir,
            work_dir,
            baseline_config;
            manifest=manifest,
            manifest_path=manifest_path,
            data_dir=data_dir
        )
        
        if status == "success"
            success_count += 1
            println("Case $id: SUCCESS")
        elseif status == "timeout"
            timeout_count += 1
            println("Case $id: TIMEOUT ($err)")
        else
            failed_count += 1
            println("Case $id: FAILED ($err)")
        end
    end
    
    # 5. Summary
    println("\n" * "="^30)
    println("SNAPSHOT GENERATION SUMMARY")
    println("Total new cases: ", n_cases)
    println("Success: ", success_count)
    println("Failed:  ", failed_count)
    println("Timeout: ", timeout_count)
    println("="^30)
    
    return manifest
end

end # module
