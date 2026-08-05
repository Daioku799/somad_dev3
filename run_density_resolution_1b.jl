#!/usr/bin/env julia

# Experiment 1B: start from one 16×16 master occupancy, aggregate it to
# 2×2/4×4/8×8/16×16, regenerate the TSV placement, and rerun the FVM.

using Dates
using JLD2
using JSON
using Printf
using Statistics

include(abspath("H2-rom/src/DensityResolutionExperiments/DensityResolutionExperiments.jl"))
using .DensityResolutionExperiments
include(abspath("H2-rom/src/SnapshotGenerator/SnapshotGenerator.jl"))
using .SnapshotGenerator

const RESOLUTIONS_1B = [2, 4, 8, 16]
const MASTER_SEED_1B = 20260805
const N_TSV_1B = 16
const NXY_1B = 240
const NZ_1B = 30
const SOLVER_1B = "pbicgstab"
const SMOOTHER_1B = "gs"
const EPSILON_1B = 1e-4
const WORK_ROOT_1B = "data/work/experiment_1b"

function parse_options(args)
    options = Dict{String, Any}(
        "target_masters" => 20,
        "time_budget_hours" => 0.0,
        "preflight_only" => false,
        "work_root" => WORK_ROOT_1B,
    )
    index = 1
    while index <= length(args)
        arg = args[index]
        if arg == "--target-masters"
            index < length(args) || error("--target-masters needs an integer")
            options["target_masters"] = parse(Int, args[index + 1])
            index += 2
        elseif arg == "--time-budget-hours"
            index < length(args) || error("--time-budget-hours needs a number")
            options["time_budget_hours"] = parse(Float64, args[index + 1])
            index += 2
        elseif arg == "--work-root"
            index < length(args) || error("--work-root needs a path")
            options["work_root"] = args[index + 1]
            index += 2
        elseif arg == "--preflight-only"
            options["preflight_only"] = true
            index += 1
        else
            error("unknown argument: $arg")
        end
    end
    options["target_masters"] > 0 || error("target master count must be positive")
    options["time_budget_hours"] >= 0 || error("time budget must be non-negative")
    return options
end

function build_resolution_config(base_config, g::Int, mu::Vector{Float64}, work_root::String)
    types = SnapshotGenerator.Sampler.H2MainExt.ConfigLoader.Types
    density = types.DensityMapConfig(g, g, mu, 0, N_TSV_1B, 1.0, Tuple{Int, Int}[])
    manufacturing = types.ManufacturingConfig(2base_config.tsv.radius, 50e-6, 0.0, 0.0)
    tsv = types.TSVConfig(
        :density,
        Tuple{Float64, Float64}[],
        base_config.tsv.radius,
        base_config.tsv.height,
        density,
        manufacturing,
        nothing,
    )
    return types.ModelConfig(
        base_config.materials,
        base_config.layers,
        tsv,
        base_config.lx,
        base_config.ly,
        base_config.pg_dpth,
        base_config.s_dpth,
        base_config.d_ufill,
        base_config.r_bump,
        true,
        abspath(work_root),
        base_config.fixed_silicon_lambda,
        base_config.epsilon,
        base_config.max_iter,
    )
end

function expanded_layout(config)
    return SnapshotGenerator.Sampler.H2MainExt.ComponentGenerator.Layout.expand_coordinates(
        config.tsv,
        config.lx,
        config.ly,
    )
end

function case_directory(work_root::String, master_id::Int, g::Int)
    joinpath(work_root, @sprintf("master_%03d", master_id), @sprintf("g%02d", g))
end

function validate_snapshot(snapshot_path::String, log_path::String)
    isfile(snapshot_path) || return (valid=false, reason="snapshot missing")
    isfile(log_path) || return (valid=false, reason="log missing")
    occursin(r"Converged at\s+\d+", read(log_path, String)) ||
        return (valid=false, reason="convergence marker missing")
    try
        return JLD2.jldopen(snapshot_path, "r") do file
            key = haskey(file, "theta") ? "theta" : (haskey(file, "temperature") ? "temperature" : "")
            isempty(key) && return (valid=false, reason="temperature field missing")
            temperature = file[key]
            expected_shape = (NXY_1B + 2, NXY_1B + 2, NZ_1B + 2)
            size(temperature) == expected_shape ||
                return (valid=false, reason="shape $(size(temperature)) != $expected_shape")
            all(isfinite, temperature) || return (valid=false, reason="non-finite temperature")
            return (
                valid=true,
                reason="ok",
                temperature_min=minimum(temperature),
                temperature_max=maximum(temperature),
                shape=collect(size(temperature)),
            )
        end
    catch error_value
        return (valid=false, reason="JLD2 validation failed: $error_value")
    end
end

function load_manifest(manifest_path::String, target_masters::Int)
    if isfile(manifest_path)
        manifest = JSON.parsefile(manifest_path)
        manifest["target_masters"] = max(Int(manifest["target_masters"]), target_masters)
        return manifest
    end
    return Dict{String, Any}(
        "schema_version" => 1,
        "experiment" => "1B-placement-generation-resolution",
        "created_at" => string(now()),
        "updated_at" => string(now()),
        "master_seed" => MASTER_SEED_1B,
        "target_masters" => target_masters,
        "n_tsv" => N_TSV_1B,
        "fvm_grid" => [NXY_1B, NXY_1B, NZ_1B],
        "resolutions" => RESOLUTIONS_1B,
        "cases" => Any[],
    )
end

function save_manifest(manifest_path::String, manifest)
    manifest["updated_at"] = string(now())
    temporary_path = manifest_path * ".tmp"
    open(temporary_path, "w") do io
        JSON.print(io, manifest, 2)
    end
    mv(temporary_path, manifest_path; force=true)
end

function update_case!(manifest, record::Dict{String, Any})
    cases = manifest["cases"]
    existing_index = findfirst(
        case -> case["master_id"] == record["master_id"] && case["resolution"] == record["resolution"],
        cases,
    )
    if existing_index === nothing
        push!(cases, record)
    else
        cases[existing_index] = record
    end
    sort!(cases; by=case -> (case["master_id"], case["resolution"]))
end

function preflight_records(masters, base_config, work_root::String)
    records = NamedTuple[]
    for (master_id, master) in enumerate(masters), g in RESOLUTIONS_1B
        mu, target_counts, capacities, block_means = coarsen_master_occupancy(master, g)
        config = build_resolution_config(base_config, g, mu, work_root)
        layout = expanded_layout(config)
        realized_counts = count_layout(
            layout,
            g;
            lx=base_config.lx,
            ly=base_config.ly,
        )
        realized_counts == target_counts ||
            error("master $master_id at $g×$g did not realize the target cell counts")
        length(layout) == N_TSV_1B ||
            error("master $master_id at $g×$g generated $(length(layout)) TSVs")
        push!(records, (
            master_id=master_id,
            resolution=g,
            input_dimension=g^2,
            tsv_count=length(layout),
            cell_capacity=only(unique(capacities)),
            sum_block_mean=sum(block_means),
            sum_placement_density=sum(mu),
        ))
    end
    return records
end

function write_preflight(work_root::String, masters, records)
    mkpath(work_root)
    open(joinpath(work_root, "preflight.tsv"), "w") do io
        println(io, join(keys(first(records)), '\t'))
        for record in records
            println(io, join(values(record), '\t'))
        end
    end
    open(joinpath(work_root, "master_occupancies.tsv"), "w") do io
        println(io, "master_id\tmaster_resolution\tn_tsv\toccupancy_flat_column_major")
        for (master_id, master) in enumerate(masters)
            println(io, "$master_id\t16\t$(sum(master))\t$(join(vec(master), ','))")
        end
    end
end

function completed_master(manifest, master_id::Int)
    records = filter(case -> case["master_id"] == master_id, manifest["cases"])
    successful = Set(
        Int(case["resolution"])
        for case in records
        if get(case, "status", "") in ("success", "cached")
    )
    return all(g -> g in successful, RESOLUTIONS_1B)
end

function successful_runtimes(manifest)
    return Float64[
        case["runtime_seconds"]
        for case in manifest["cases"]
        if get(case, "status", "") == "success" && get(case, "runtime_seconds", 0.0) > 0
    ]
end

function run_case!(
    manifest,
    manifest_path::String,
    master_id::Int,
    master,
    g::Int,
    base_config,
    solver_dir::String,
    work_root::String,
)
    mu, target_counts, capacities, block_means = coarsen_master_occupancy(master, g)
    config = build_resolution_config(base_config, g, mu, work_root)
    layout = expanded_layout(config)
    length(layout) == N_TSV_1B || error("preflight count changed before execution")

    directory = case_directory(work_root, master_id, g)
    mkpath(directory)
    snapshot_path = abspath(joinpath(directory, "snapshot.jld2"))
    log_path = abspath(joinpath(directory, "output.log"))
    validation = validate_snapshot(snapshot_path, log_path)

    base_record = Dict{String, Any}(
        "master_id" => master_id,
        "resolution" => g,
        "case_id" => master_id * 100 + g,
        "mu" => mu,
        "target_cell_counts" => vec(target_counts),
        "cell_capacity" => only(unique(capacities)),
        "block_means" => vec(block_means),
        "tsv_count" => length(layout),
        "snapshot_path" => relpath(snapshot_path, pwd()),
        "log_path" => relpath(log_path, pwd()),
    )

    if validation.valid
        merge!(base_record, Dict{String, Any}(
            "status" => "cached",
            "runtime_seconds" => 0.0,
            "validation" => Dict(string(key) => value for (key, value) in pairs(validation)),
        ))
        update_case!(manifest, base_record)
        save_manifest(manifest_path, manifest)
        println(@sprintf("[cached] master %03d, %2d×%-2d", master_id, g, g))
        return 0.0, true
    end

    if isfile(snapshot_path)
        backup_path = snapshot_path * ".invalid_" * Dates.format(now(), "yyyymmdd_HHMMSS")
        mv(snapshot_path, backup_path)
        println("Moved invalid snapshot to $backup_path")
    end

    case = SnapshotGenerator.Types.SnapshotCase(
        master_id * 100 + g,
        "pending",
        mu,
        "",
        0.0,
    )
    SnapshotGenerator.Runner.generate_case_configs(case, config, directory)

    run_script = abspath(joinpath(solver_dir, "run.jl"))
    command = `julia --project=$(abspath(solver_dir)) $run_script $NXY_1B $NXY_1B $NZ_1B $SOLVER_1B $SMOOTHER_1B $EPSILON_1B sequential true --snapshot $snapshot_path`
    println(@sprintf("[start ] master %03d, %2d×%-2d at %s", master_id, g, g, Dates.format(now(), "HH:MM:SS")))
    started_at = time()
    process_ok = false
    open(log_path, "w") do io
        process_ok = success(run(pipeline(setenv(command, dir=directory), stdout=io, stderr=io); wait=true))
    end
    runtime = time() - started_at
    validation = validate_snapshot(snapshot_path, log_path)
    success_case = process_ok && validation.valid

    merge!(base_record, Dict{String, Any}(
        "status" => success_case ? "success" : "failed",
        "runtime_seconds" => runtime,
        "finished_at" => string(now()),
        "validation" => Dict(string(key) => value for (key, value) in pairs(validation)),
    ))
    update_case!(manifest, base_record)
    save_manifest(manifest_path, manifest)

    if success_case
        println(@sprintf("[done  ] master %03d, %2d×%-2d in %.1f s", master_id, g, g, runtime))
    else
        println(@sprintf("[failed] master %03d, %2d×%-2d: %s", master_id, g, g, validation.reason))
    end
    return runtime, success_case
end

function run_experiment_1b(args=ARGS)
    options = parse_options(args)
    target_masters = Int(options["target_masters"])
    time_budget_hours = Float64(options["time_budget_hours"])
    work_root = abspath(String(options["work_root"]))
    mkpath(work_root)

    masters = generate_master_occupancies(
        target_masters;
        n_tsv=N_TSV_1B,
        seed=MASTER_SEED_1B,
    )
    base_config = SnapshotGenerator.Runner.default_model_config()
    records = preflight_records(masters, base_config, work_root)
    write_preflight(work_root, masters, records)
    println("Preflight passed: $(length(records)) matched master/resolution cases, all with 16 TSVs")
    options["preflight_only"] && return

    manifest_path = joinpath(work_root, "manifest.json")
    manifest = load_manifest(manifest_path, target_masters)
    save_manifest(manifest_path, manifest)
    solver_dir = abspath("H2-main-ext")
    started_at = time()
    deadline = time_budget_hours > 0 ? started_at + time_budget_hours * 3600 : Inf

    for (master_id, master) in enumerate(masters)
        completed_master(manifest, master_id) && continue

        runtimes = successful_runtimes(manifest)
        estimated_case_seconds = isempty(runtimes) ? 240.0 : mean(runtimes)
        estimated_group_seconds = 4estimated_case_seconds
        remaining_seconds = deadline - time()
        if isfinite(deadline) && remaining_seconds < 1.1estimated_group_seconds
            @printf(
                "Stopping before master %03d: %.1f min remain, %.1f min estimated for a complete group\n",
                master_id,
                remaining_seconds / 60,
                estimated_group_seconds / 60,
            )
            break
        end

        println("\n=== Master $master_id / $target_masters ===")
        for g in RESOLUTIONS_1B
            _, success_case = run_case!(
                manifest,
                manifest_path,
                master_id,
                master,
                g,
                base_config,
                solver_dir,
                work_root,
            )
            success_case || break
        end
    end

    completed = count(master_id -> completed_master(manifest, master_id), 1:target_masters)
    elapsed_hours = (time() - started_at) / 3600
    println("\nExperiment 1B run finished: $completed complete masters / $target_masters target")
    @printf("Elapsed execution time: %.3f h\n", elapsed_hours)
    println("Manifest: $manifest_path")
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_experiment_1b()
end
