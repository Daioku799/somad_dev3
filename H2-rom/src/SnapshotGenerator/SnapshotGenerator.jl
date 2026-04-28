module SnapshotGenerator

include("Manifest.jl")
include("Sampler.jl")
include("Runner.jl")

using .Manifest
using .Sampler
using .Runner
using Dates

export run_generator

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
    
    # 1. Load/Initialize Manifest
    manifest = load_manifest(manifest_path)
    println("Manifest loaded. Current cases: ", length(manifest.cases))
    
    # 2. Generate new samples
    println("Generating $n_cases new samples using LHS...")
    new_params = generate_samples(n_cases)
    
    # 3. Add cases to manifest
    pending_ids = Int[]
    for p in new_params
        case_dict = Dict(
            "radius" => p.radius,
            "count" => p.count,
            "coords" => p.coords
        )
        c = add_case!(manifest, case_dict)
        push!(pending_ids, c.id)
    end
    save_manifest(manifest, manifest_path)
    
    # 4. Run loop
    println("Starting batch execution of ", length(pending_ids), " cases...")
    
    success_count = 0
    failed_count = 0
    
    for id in pending_ids
        case = filter(c -> c.id == id, manifest.cases)[1]
        
        status, snap_work_path, err = run_simulation_case(case, solver_dir, work_dir)
        
        if status == "success"
            # Move snapshot to raw dir
            snap_final_path = joinpath(raw_dir, "snapshot_$(id).jld2")
            mv(snap_work_path, snap_final_path, force=true)
            
            update_case_status!(manifest, id, "success", snapshot=snap_final_path)
            success_count += 1
            println("Case $id: SUCCESS")
        else
            update_case_status!(manifest, id, "failed", error=err)
            failed_count += 1
            println("Case $id: FAILED ($err)")
        end
        
        # Save manifest frequently
        save_manifest(manifest, manifest_path)
    end
    
    # 5. Summary
    println("\n" * "="^30)
    println("SNAPSHOT GENERATION SUMMARY")
    println("Total new cases: ", n_cases)
    println("Success: ", success_count)
    println("Failed:  ", failed_count)
    println("="^30)
    
    return manifest
end

end # module
