module Runner

using JSON
using ..Sampler
using ..Manifest

export run_simulation_case

"""
    run_simulation_case(case::SimulationCase, solver_dir::String, work_base::String)

Run a single FVM simulation case.
1. Create a work subdirectory.
2. Generate config.json and tsv_config.json.
3. Call run.jl via Cmd.
4. Return status and error message if any.
"""
function run_simulation_case(case::SimulationCase, solver_dir::String, work_base::String)
    case_dir = joinpath(work_base, "case_$(case.id)")
    mkpath(case_dir)
    
    # 1. Generate TSV Config
    tsv_config = Dict(
        "tsv_mode" => "manual",
        "tsv_radius" => case.params["radius"],
        "manual_coordinates" => case.params["coords"]
    )
    
    # 2. Generate Base Config (copying defaults but updating dimensions if needed)
    # For now, we assume a template config.json exists or use a default structure
    # Let's use a default structure based on H2-main-ext requirements
    base_config = Dict(
        "lx" => 1.2e-3, "ly" => 1.2e-3,
        "pg_dpth" => 5.0e-6, "s_dpth" => 1.0e-4, "d_ufill" => 5.0e-5, "r_bump" => 3.0e-5,
        "materials" => Dict(
            "Copper" => Dict("id"=>1, "λ"=>386.0, "ρ"=>8960.0, "C"=>383.0),
            "Silicon" => Dict("id"=>2, "λ"=>149.0, "ρ"=>2330.0, "C"=>720.0),
            "Solder" => Dict("id"=>3, "λ"=>50.0, "ρ"=>8500.0, "C"=>197.0),
            "PCB" => Dict("id"=>4, "λ"=>0.4, "ρ"=>1850.0, "C"=>1000.0),
            "Heatsink" => Dict("id"=>5, "λ"=>222.0, "ρ"=>2700.0, "C"=>921.0),
            "Resin" => Dict("id"=>6, "λ"=>1.5, "ρ"=>2590.0, "C"=>1050.0),
            "PowerSource" => Dict("id"=>7, "λ"=>149.0, "ρ"=>2330.0, "C"=>720.0)
        ),
        "layers" => [
            Dict("name"=>"Substrate", "thickness"=>5.0e-5, "divisions"=>1, "grading"=>1.0),
            Dict("name"=>"Underfill1", "thickness"=>5.0e-5, "divisions"=>1, "grading"=>1.0),
            Dict("name"=>"Silicon1", "thickness"=>1.0e-4, "divisions"=>1, "grading"=>1.0),
            Dict("name"=>"Underfill2", "thickness"=>5.0e-5, "divisions"=>1, "grading"=>1.0),
            Dict("name"=>"Silicon2", "thickness"=>1.0e-4, "divisions"=>1, "grading"=>1.0),
            Dict("name"=>"Underfill3", "thickness"=>5.0e-5, "divisions"=>1, "grading"=>1.0),
            Dict("name"=>"Silicon3", "thickness"=>1.0e-4, "divisions"=>1, "grading"=>1.0),
            Dict("name"=>"Underfill4", "thickness"=>5.0e-5, "divisions"=>1, "grading"=>1.0),
            Dict("name"=>"Heatsink", "thickness"=>5.0e-5, "divisions"=>5, "grading"=>1.0)
        ]
    )

    open(joinpath(case_dir, "config.json"), "w") do io
        JSON.print(io, base_config)
    end
    open(joinpath(case_dir, "tsv_config.json"), "w") do io
        JSON.print(io, tsv_config)
    end

    # 3. Execute Solver
    # We use NX=240, NY=240, NZ=30 as standard
    snapshot_file = abspath(joinpath(case_dir, "snapshot.jld2"))
    
    cmd = `julia --project=$(solver_dir) $(joinpath(solver_dir, "run.jl")) 240 240 30 pbicgstab gs 1e-4 sequential true --snapshot $(snapshot_file)`
    
    println("Starting Case $(case.id)...")
    
    log_file = joinpath(case_dir, "output.log")
    
    success = false
    error_msg = ""
    
    try
        # Run with timeout (e.g., 600 seconds)
        # Note: Base.run doesn't have a direct timeout, we might need a wrapper or use a Task
        open(log_file, "w") do out
            run(pipeline(cmd, stdout=out, stderr=out))
        end
        success = true
    catch e
        error_msg = string(e)
        println("Case $(case.id) failed: $error_msg")
    end

    if success && isfile(snapshot_file)
        return "success", snapshot_file, ""
    else
        return "failed", "", error_msg
    end
end

end # module
