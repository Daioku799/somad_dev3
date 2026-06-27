module Runner

using JSON
using ..Sampler
using ..Sampler: H2MainExt
using ..Manifest
using ..Types: SnapshotCase
using .H2MainExt.ConfigLoader: ModelConfig, TSVConfig, DensityMapConfig, ManufacturingConfig, generate_test_config

export run_simulation_case, prepare_work_dir, generate_case_configs

"""
    prepare_work_dir(case::SnapshotCase, work_base::String) -> String

Create a clean work directory for the given case.
If the directory already exists, clean its contents.
Returns the absolute path to the prepared directory.
"""
function prepare_work_dir(case::SnapshotCase, work_base::String)
    case_dir = joinpath(work_base, "case_$(case.id)")
    if isdir(case_dir)
        # Clean up directory contents safely
        for item in readdir(case_dir, join=true)
            rm(item, recursive=true, force=true)
        end
    else
        mkpath(case_dir)
    end
    return abspath(case_dir)
end

"""
    generate_case_configs(case::SnapshotCase, config::ModelConfig, case_dir::String)

Write both `config.json` and `tsv_config.json` to the `case_dir`.
Ensure `tsv_mode` is "density", and the case's adjusted `mu` is correctly written.
Validate the generated configuration using ComponentGenerator.
"""
function generate_case_configs(case::SnapshotCase, config::ModelConfig, case_dir::String)
    # Validate density map presence
    if config.tsv.density === nothing
        error("density_map configuration is missing in config.tsv")
    end
    
    # 1. Map config to config.json format
    materials_dict = Dict{String, Any}()
    for mat in config.materials
        materials_dict[mat.name] = Dict(
            "id" => mat.id,
            "λ" => mat.lambda,
            "ρ" => mat.rho,
            "C" => mat.cp
        )
    end
    
    layers_array = Any[]
    for layer in config.layers
        push!(layers_array, Dict(
            "name" => layer.name,
            "thickness" => layer.thickness,
            "divisions" => layer.divisions,
            "grading" => layer.grading
        ))
    end
    
    dimensions_dict = Dict(
        "h_tsv" => config.tsv.height,
        "pg_dpth" => config.pg_dpth,
        "s_dpth" => config.s_dpth,
        "d_ufill" => config.d_ufill,
        "r_bump" => config.r_bump
    )
    
    config_dict = Dict(
        "lx" => config.lx,
        "ly" => config.ly,
        "materials" => materials_dict,
        "layers" => layers_array,
        "dimensions" => dimensions_dict,
        "snapshot_enabled" => config.snapshot_enabled,
        "snapshot_dir" => config.snapshot_dir,
        "fixed_silicon_lambda" => config.fixed_silicon_lambda,
        "epsilon" => config.epsilon,
        "max_iter" => config.max_iter
    )
    
    # 2. Map config and case.mu to tsv_config.json format
    density = config.tsv.density
    density_map_dict = Dict(
        "gx" => density.gx,
        "gy" => density.gy,
        "mu" => case.mu,
        "n_min" => density.n_min,
        "n_max" => density.n_max,
        "rho_cell_max" => density.rho_cell_max,
        "prohibited_cells" => [ [cell[1], cell[2]] for cell in density.prohibited_cells ]
    )
    
    tsv_config_dict = Dict{String, Any}(
        "tsv_mode" => "density",
        "tsv_radius" => config.tsv.radius,
        "density_map" => density_map_dict
    )
    
    if config.tsv.manufacturing !== nothing
        m = config.tsv.manufacturing
        tsv_config_dict["manufacturing"] = Dict(
            "d_tsv" => m.d_tsv,
            "p_min" => m.p_min,
            "ar_min" => m.ar_min,
            "ar_max" => m.ar_max
        )
    end
    
    if config.tsv.ga !== nothing
        ga = config.tsv.ga
        tsv_config_dict["ga_settings"] = Dict(
            "n_pop" => ga.n_pop,
            "n_gen" => ga.n_gen,
            "cx_rate" => ga.cx_rate,
            "mut_rate" => ga.mut_rate
        )
    end
    
    # Write JSON files to case_dir
    config_path = joinpath(case_dir, "config.json")
    tsv_config_path = joinpath(case_dir, "tsv_config.json")
    
    open(config_path, "w") do io
        JSON.print(io, config_dict)
    end
    
    open(tsv_config_path, "w") do io
        JSON.print(io, tsv_config_dict)
    end
    
    # Verify generated configs can be successfully loaded and expanded by ComponentGenerator
    try
        loaded_config = H2MainExt.ConfigLoader.load_config(config_path, tsv_config_path)
        H2MainExt.ComponentGenerator.generate_all_components(loaded_config)
    catch e
        error("Generated configuration fails layout expansion or validation: $e")
    end
end

function default_model_config()
    base_config = generate_test_config()
    density_map = DensityMapConfig(4, 4, fill(0.5, 16), 0, 16, 1.0, Tuple{Int, Int}[])
    manufacturing = ManufacturingConfig(2*base_config.tsv.radius, 50e-6, 0.0, 0.0)
    tsv_config = TSVConfig(:density, Tuple{Float64, Float64}[], base_config.tsv.radius, base_config.tsv.height, density_map, manufacturing, nothing)

    return ModelConfig(
        base_config.materials,
        base_config.layers,
        tsv_config,
        base_config.lx,
        base_config.ly,
        base_config.pg_dpth,
        base_config.s_dpth,
        base_config.d_ufill,
        base_config.r_bump,
        base_config.snapshot_enabled,
        base_config.snapshot_dir,
        base_config.fixed_silicon_lambda,
        base_config.epsilon,
        base_config.max_iter
    )
end

"""
    run_simulation_case(case::SnapshotCase, solver_dir::String, work_base::String, config::ModelConfig = default_model_config(); timeout_sec::Int=300)

Run a single FVM simulation case.
1. Create a work subdirectory.
2. Generate config.json and tsv_config.json using `generate_case_configs`.
3. Call run.jl via Cmd.
4. Return status and error message if any.
"""
function run_simulation_case(case::SnapshotCase, solver_dir::String, work_base::String, config::ModelConfig = default_model_config(); timeout_sec::Int=300)
    case_dir = prepare_work_dir(case, work_base)
    
    # Generate Configs
    generate_case_configs(case, config, case_dir)

    # 3. Execute Solver
    # We use NX=240, NY=240, NZ=30 as standard
    snapshot_file = abspath(joinpath(case_dir, "snapshot.jld2"))
    abs_solver_dir = abspath(solver_dir)
    abs_run_jl = abspath(joinpath(abs_solver_dir, "run.jl"))
    
    cmd = `julia --project=$(abs_solver_dir) $(abs_run_jl) 240 240 30 pbicgstab gs 1e-4 sequential true --snapshot $(snapshot_file)`
    
    println("Starting Case $(case.id)...")
    
    log_file = joinpath(case_dir, "output.log")
    
    status = "failed"
    error_msg = ""
    timeout_expired = false
    
    try
        open(log_file, "w") do out
            proc = run(pipeline(setenv(cmd, dir=case_dir), stdout=out, stderr=out), wait=false)
            
            t = Timer(timeout_sec) do timer
                timeout_expired = true
                if process_running(proc)
                    kill(proc)
                end
            end
            
            try
                wait(proc)
            finally
                close(t)
            end
            
            if timeout_expired
                status = "timeout"
                error_msg = "Solver simulation timed out after $timeout_sec seconds."
                println("Case $(case.id) timed out: $error_msg")
            elseif !success(proc)
                status = "failed"
                error_msg = "Solver exited with non-zero exit code: $(proc.exitcode)"
                println("Case $(case.id) failed: $error_msg")
            else
                if isfile(snapshot_file)
                    status = "success"
                else
                    status = "failed"
                    error_msg = "Solver finished successfully, but snapshot file was not generated."
                    println("Case $(case.id) failed: $error_msg")
                end
            end
        end
    catch e
        status = "failed"
        error_msg = string(e)
        println("Case $(case.id) failed to start or run: $error_msg")
    end

    if status == "success"
        return "success", snapshot_file, ""
    elseif status == "timeout"
        return "timeout", "", error_msg
    else
        return "failed", "", error_msg
    end
end

end # module
