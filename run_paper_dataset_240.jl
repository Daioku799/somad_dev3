#!/usr/bin/env julia

# Build the versioned 240x240 FVM dataset shared by ROM experiments 1A/2/3/4.
# The run is resumable: every finished case is validated and recorded atomically.

using Dates
using JLD2
using JSON
using LatinHypercubeSampling
using LinearAlgebra
using Printf
using Random
using SHA
using Statistics

include(abspath("H2-rom/src/SnapshotGenerator/SnapshotGenerator.jl"))
using .SnapshotGenerator

const DATA_ROOT = abspath("data/paper_240_v1")
const SPLIT_SPECS = [
    (name="train", n=80, seed=20260806, first_id=1, anchors=true),
    (name="validation", n=10, seed=20260807, first_id=81, anchors=false),
    (name="test", n=10, seed=20260808, first_id=91, anchors=false),
]
const PILOT_GRIDS = [60, 120, 240, 480]
const FINAL_NXY = 240
const NZ = 30
const GX = 4
const GY = 4
const CELL_CAPACITY = 9
const GLOBAL_TSV_LIMIT = 120
const TSV_RADIUS = 20e-6
const MIN_PITCH = 80e-6
const AMBIENT_TEMPERATURE = 300.0
const MIN_FREE_BYTES = 20 * 1024^3
const EXPECTED_Z_FACES = 1e-6 .* Float64[
    0, 5, 45, 50, 55, 95, 100, 105, 190, 195, 200,
    205, 245, 250, 255, 340, 345, 350, 355, 395, 400,
    405, 490, 495, 500, 505, 545, 550, 555, 595, 600,
]

function parse_options(args)
    options = Dict{String, Any}(
        "phase" => "all",
        "data_root" => DATA_ROOT,
        "pilot_timeout" => 7200,
        "case_timeout" => 1800,
    )
    i = 1
    while i <= length(args)
        if args[i] == "--phase"
            i < length(args) || error("--phase requires prepare, pilot, dataset, or all")
            options["phase"] = args[i + 1]
            i += 2
        elseif args[i] == "--data-root"
            i < length(args) || error("--data-root requires a path")
            options["data_root"] = abspath(args[i + 1])
            i += 2
        elseif args[i] == "--pilot-timeout"
            i < length(args) || error("--pilot-timeout requires seconds")
            options["pilot_timeout"] = parse(Int, args[i + 1])
            i += 2
        elseif args[i] == "--case-timeout"
            i < length(args) || error("--case-timeout requires seconds")
            options["case_timeout"] = parse(Int, args[i + 1])
            i += 2
        else
            error("unknown argument: $(args[i])")
        end
    end
    options["phase"] in ("prepare", "pilot", "dataset", "all") ||
        error("phase must be prepare, pilot, dataset, or all")
    return options
end

function latin_hypercube(n::Int, dims::Int, seed::Int)
    Random.seed!(seed)
    integer_plan = randomLHC(n, dims)
    return (integer_plan .- rand(Float64, size(integer_plan))) ./ n
end

function representative_anchors()
    cx = (GX + 1) / 2
    cy = (GY + 1) / 2
    dmax = sqrt((cx - 1)^2 + (cy - 1)^2)
    uniform = ones(GX * GY)
    center = vec([
        clamp(1 - sqrt((i - cx)^2 + (j - cy)^2) / dmax, 0, 1)
        for i in 1:GX, j in 1:GY
    ])
    corners = vec([
        clamp(sqrt((i - cx)^2 + (j - cy)^2) / dmax, 0, 1)
        for i in 1:GX, j in 1:GY
    ])
    return [uniform, center, corners]
end

function build_model_config(mu::Vector{Float64}, data_root::String)
    base = SnapshotGenerator.Runner.default_model_config()
    types = SnapshotGenerator.Sampler.H2MainExt.ConfigLoader.Types
    density = types.DensityMapConfig(GX, GY, mu, 0, GLOBAL_TSV_LIMIT, 1.0, Tuple{Int, Int}[])
    manufacturing = types.ManufacturingConfig(2TSV_RADIUS, MIN_PITCH, 0.0, 0.0)
    tsv = types.TSVConfig(
        :density,
        Tuple{Float64, Float64}[],
        TSV_RADIUS,
        base.tsv.height,
        density,
        manufacturing,
        nothing,
    )
    return types.ModelConfig(
        base.materials,
        base.layers,
        tsv,
        base.lx,
        base.ly,
        base.pg_dpth,
        base.s_dpth,
        base.d_ufill,
        base.r_bump,
        true,
        data_root,
        base.fixed_silicon_lambda,
        1e-6,
        8000,
    )
end

function expanded_layout(config)
    SnapshotGenerator.Sampler.H2MainExt.ComponentGenerator.Layout.expand_coordinates(
        config.tsv,
        config.lx,
        config.ly,
    )
end

function adjust_and_quantize(raw_mu::Vector{Float64}, data_root::String)
    layout_module = SnapshotGenerator.Sampler.H2MainExt.ComponentGenerator.Layout
    provisional = build_model_config(raw_mu, data_root)
    capacities = layout_module.get_cell_capacities(provisional.tsv, provisional.lx, provisional.ly)
    all(capacities .== CELL_CAPACITY) ||
        error("expected 4x4 cell capacity $CELL_CAPACITY, got $(unique(capacities))")
    adjusted = layout_module.adjust_density_constraints(raw_mu, capacities, GLOBAL_TSV_LIMIT)
    counts = round.(Int, adjusted .* vec(capacities))
    quantized = counts ./ vec(capacities)
    return adjusted, quantized, counts
end

function minimum_pair_distance(layout)
    length(layout) < 2 && return Inf
    minimum(
        hypot(layout[i].x - layout[j].x, layout[i].y - layout[j].y)
        for i in eachindex(layout) for j in (i + 1):length(layout)
    )
end

function layout_signature(layout)
    coordinates = sort([(point.x, point.y) for point in layout])
    bytes2hex(sha256(join((@sprintf("%.12e,%.12e", x, y) for (x, y) in coordinates), ";")))
end

function generate_cases(data_root::String)
    cases = Dict{String, Any}[]
    signatures = Set{String}()
    anchors = representative_anchors()
    for spec in SPLIT_SPECS
        raw = latin_hypercube(spec.n, GX * GY, spec.seed)
        if spec.anchors
            for i in eachindex(anchors)
                raw[i, :] .= anchors[i]
            end
        end
        for local_id in 1:spec.n
            case_id = spec.first_id + local_id - 1
            raw_mu = collect(raw[local_id, :])
            adjusted_mu, mu, counts = adjust_and_quantize(raw_mu, data_root)
            config = build_model_config(mu, data_root)
            layout = expanded_layout(config)
            length(layout) == sum(counts) || error("case $case_id count/layout mismatch")
            distance = minimum_pair_distance(layout)
            distance + 1e-12 >= MIN_PITCH ||
                error("case $case_id violates p_min: $(distance * 1e6) um")
            all(point ->
                point.x - TSV_RADIUS >= 0.1e-3 - 1e-12 &&
                point.x + TSV_RADIUS <= 1.1e-3 + 1e-12 &&
                point.y - TSV_RADIUS >= 0.1e-3 - 1e-12 &&
                point.y + TSV_RADIUS <= 1.1e-3 + 1e-12,
                layout,
            ) || error("case $case_id violates the silicon boundary")
            signature = layout_signature(layout)
            signature in signatures && error("duplicate discrete layout for case $case_id")
            push!(signatures, signature)
            push!(cases, Dict{String, Any}(
                "case_id" => case_id,
                "split" => spec.name,
                "split_seed" => spec.seed,
                "split_local_id" => local_id,
                "raw_lhs_mu" => raw_mu,
                "constraint_adjusted_mu" => adjusted_mu,
                "mu" => mu,
                "cell_counts" => counts,
                "tsv_count" => length(layout),
                "minimum_pitch_m" => distance,
                "layout_signature_sha256" => signature,
                "coordinates_m" => [[point.x, point.y] for point in layout],
            ))
        end
    end
    return cases
end

function atomic_json(path::String, value)
    mkpath(dirname(path))
    temporary = path * ".tmp"
    open(temporary, "w") do io
        JSON.print(io, value, 2)
        write(io, '\n')
    end
    mv(temporary, path; force=true)
end

function initial_manifest(data_root::String, cases)
    Dict{String, Any}(
        "schema_version" => 1,
        "dataset" => "paper_240_v1",
        "created_at" => string(now()),
        "updated_at" => string(now()),
        "status" => "prepared",
        "current" => nothing,
        "conditions" => Dict(
            "domain_m" => [1.2e-3, 1.2e-3, 0.6e-3],
            "final_grid" => [FINAL_NXY, FINAL_NXY, NZ],
            "pilot_grids" => PILOT_GRIDS,
            "density_grid" => [GX, GY],
            "tsv_radius_m" => TSV_RADIUS,
            "minimum_pitch_m" => MIN_PITCH,
            "global_tsv_limit" => GLOBAL_TSV_LIMIT,
            "solver" => "pbicgstab",
            "smoother" => "gs",
            "tolerance" => 1e-4,
            "max_iterations" => 8000,
            "ambient_temperature_K" => AMBIENT_TEMPERATURE,
            "expected_z_faces_m" => EXPECTED_Z_FACES,
        ),
        "splits" => [Dict(pairs(spec)) for spec in SPLIT_SPECS],
        "cases" => cases,
        "runs" => Dict{String, Any}(),
        "pilot" => Dict{String, Any}(
            "status" => "pending",
            "case_ids" => Int[],
            "gate" => Dict(
                "rise_relative_l2_max" => 0.005,
                "tmax_difference_K_max" => 0.1,
                "copper_volume_relative_difference_max" => 0.05,
            ),
        ),
    )
end

function load_or_prepare(data_root::String)
    mkpath(data_root)
    manifest_path = joinpath(data_root, "manifest.json")
    generated = generate_cases(data_root)
    if isfile(manifest_path)
        manifest = JSON.parsefile(manifest_path)
        existing = manifest["cases"]
        length(existing) == length(generated) || error("existing manifest case count differs")
        for (old, new) in zip(existing, generated)
            old["case_id"] == new["case_id"] || error("existing manifest case IDs differ")
            old["layout_signature_sha256"] == new["layout_signature_sha256"] ||
                error("existing case $(old["case_id"]) layout differs; refusing to overwrite")
        end
        return manifest, manifest_path
    end
    manifest = initial_manifest(data_root, generated)
    atomic_json(manifest_path, manifest)
    return manifest, manifest_path
end

function save_manifest(path::String, manifest)
    manifest["updated_at"] = string(now())
    atomic_json(path, manifest)
end

function write_plan(data_root::String, manifest)
    plan_path = joinpath(data_root, "case_plan.tsv")
    isfile(plan_path) && return
    open(plan_path, "w") do io
        println(io, "case_id\tsplit\tsplit_seed\ttsv_count\tminimum_pitch_um\tlayout_sha256\tcell_counts_column_major")
        for case in manifest["cases"]
            println(io, join([
                case["case_id"], case["split"], case["split_seed"], case["tsv_count"],
                @sprintf("%.6f", case["minimum_pitch_m"] * 1e6),
                case["layout_signature_sha256"], join(case["cell_counts"], ','),
            ], '\t'))
        end
    end
end

function case_by_id(manifest, case_id::Int)
    index = findfirst(case -> case["case_id"] == case_id, manifest["cases"])
    index === nothing && error("case $case_id not found")
    return manifest["cases"][index]
end

function run_key(case_id::Int, nxy::Int)
    @sprintf("case_%03d_n%04d", case_id, nxy)
end

function run_directory(data_root::String, case_id::Int, nxy::Int)
    if nxy == FINAL_NXY
        return joinpath(data_root, "cases", @sprintf("case_%03d", case_id))
    end
    joinpath(data_root, "pilot", @sprintf("case_%03d", case_id), @sprintf("n%04d", nxy))
end

function file_sha256(path::String)
    open(path, "r") do io
        bytes2hex(sha256(io))
    end
end

function validate_snapshot(snapshot_path::String, log_path::String, nxy::Int)
    isfile(snapshot_path) || return (valid=false, reason="snapshot missing")
    isfile(log_path) || return (valid=false, reason="log missing")
    occursin(r"Converged at\s+\d+", read(log_path, String)) ||
        return (valid=false, reason="convergence marker missing")
    try
        return jldopen(snapshot_path, "r") do file
            required = ["theta", "id_map", "lambda", "z_centers", "z_faces", "nx", "ny", "nz"]
            all(key -> haskey(file, key), required) || return (valid=false, reason="required JLD2 key missing")
            expected_shape = (nxy + 2, nxy + 2, NZ + 2)
            for key in ["theta", "id_map", "lambda"]
                size(file[key]) == expected_shape ||
                    return (valid=false, reason="$key shape $(size(file[key])) != $expected_shape")
            end
            file["nx"] == nxy && file["ny"] == nxy && file["nz"] == NZ ||
                return (valid=false, reason="grid metadata mismatch")
            all(isfinite, file["theta"]) && all(isfinite, file["lambda"]) ||
                return (valid=false, reason="non-finite field")
            zfaces = file["z_faces"]
            length(zfaces) == length(EXPECTED_Z_FACES) &&
                maximum(abs.(zfaces .- EXPECTED_Z_FACES)) <= 1e-12 ||
                return (valid=false, reason="z-face coordinates differ from H2-main Zcase2")
            (
                valid=true,
                reason="ok",
                shape=collect(expected_shape),
                temperature_min_K=minimum(file["theta"]),
                temperature_max_K=maximum(file["theta"]),
                snapshot_sha256=file_sha256(snapshot_path),
            )
        end
    catch error_value
        return (valid=false, reason="JLD2 validation failed: $(sprint(showerror, error_value))")
    end
end

function quarantine_invalid(directory::String, snapshot_path::String, log_path::String)
    (!isfile(snapshot_path) && !isfile(log_path)) && return
    quarantine = joinpath(directory, "quarantine", Dates.format(now(), "yyyymmdd_HHMMSS"))
    mkpath(quarantine)
    for path in [snapshot_path, log_path]
        isfile(path) && mv(path, joinpath(quarantine, basename(path)))
    end
end

function free_bytes(path::String)
    output = read(`df --output=avail -B1 $path`, String)
    parse(Int, split(strip(output), '\n')[end])
end

function run_one!(manifest, manifest_path::String, data_root::String, case, nxy::Int, timeout_seconds::Int)
    key = run_key(case["case_id"], nxy)
    directory = run_directory(data_root, case["case_id"], nxy)
    mkpath(directory)
    snapshot_path = joinpath(directory, "snapshot.jld2")
    log_path = joinpath(directory, "output.log")
    validation = validate_snapshot(snapshot_path, log_path, nxy)
    if validation.valid
        manifest["runs"][key] = Dict(
            "status" => "cached", "case_id" => case["case_id"], "nxy" => nxy,
            "snapshot_path" => relpath(snapshot_path, pwd()), "log_path" => relpath(log_path, pwd()),
            "validation" => validation,
        )
        save_manifest(manifest_path, manifest)
        println(@sprintf("[cached] case %03d grid %4d", case["case_id"], nxy))
        flush(stdout)
        return true
    end

    free_bytes(data_root) >= MIN_FREE_BYTES || error("less than 20 GiB free; stopping safely")
    quarantine_invalid(directory, snapshot_path, log_path)
    config = build_model_config(Float64.(case["mu"]), data_root)
    snapshot_case = SnapshotGenerator.Types.SnapshotCase(case["case_id"], "pending", Float64.(case["mu"]), "", 0.0)
    SnapshotGenerator.Runner.generate_case_configs(snapshot_case, config, directory)
    atomic_json(joinpath(directory, "case_metadata.json"), case)

    record = Dict{String, Any}(
        "status" => "running", "case_id" => case["case_id"], "split" => case["split"], "nxy" => nxy,
        "started_at" => string(now()), "snapshot_path" => relpath(snapshot_path, pwd()),
        "log_path" => relpath(log_path, pwd()), "layout_signature_sha256" => case["layout_signature_sha256"],
    )
    manifest["runs"][key] = record
    manifest["current"] = Dict("key" => key, "case_id" => case["case_id"], "nxy" => nxy, "started_at" => record["started_at"])
    save_manifest(manifest_path, manifest)

    solver_dir = abspath("H2-main-ext")
    run_script = joinpath(solver_dir, "run.jl")
    command = `julia --project=$solver_dir $run_script $nxy $nxy $NZ pbicgstab gs 1e-4 sequential true --snapshot $snapshot_path`
    println(@sprintf("[start ] case %03d grid %4d at %s", case["case_id"], nxy, Dates.format(now(), "HH:MM:SS")))
    flush(stdout)
    started = time()
    timed_out = false
    process_ok = false
    open(log_path, "w") do io
        process = run(pipeline(setenv(command, dir=directory), stdout=io, stderr=io); wait=false)
        while process_running(process)
            if time() - started > timeout_seconds
                timed_out = true
                kill(process)
                break
            end
            sleep(2)
        end
        wait(process)
        process_ok = !timed_out && success(process)
    end
    runtime = time() - started
    validation = validate_snapshot(snapshot_path, log_path, nxy)
    ok = process_ok && validation.valid
    merge!(record, Dict{String, Any}(
        "status" => ok ? "success" : (timed_out ? "timeout" : "failed"),
        "finished_at" => string(now()), "runtime_seconds" => runtime,
        "validation" => validation,
    ))
    manifest["runs"][key] = record
    manifest["current"] = nothing
    save_manifest(manifest_path, manifest)
    println(@sprintf("[%s] case %03d grid %4d in %.1f s: %s",
        ok ? "done" : "FAIL", case["case_id"], nxy, runtime, validation.reason))
    flush(stdout)
    return ok
end

function pilot_case_ids(manifest)
    train_cases = filter(case -> case["split"] == "train", manifest["cases"])
    typical = train_cases[argmin(abs.([case["tsv_count"] - 73 for case in train_cases]))]["case_id"]
    unique([1, 2, typical])
end

function block_average(field::Array{Float64, 3}, factor::Int)
    nx, ny, nz = size(field)
    nx % factor == 0 && ny % factor == 0 || error("non-integer XY coarsening factor")
    coarse = zeros(Float64, nx ÷ factor, ny ÷ factor, nz)
    for k in 1:nz, j in axes(coarse, 2), i in axes(coarse, 1)
        coarse[i, j, k] = mean(@view field[(factor * (i - 1) + 1):(factor * i), (factor * (j - 1) + 1):(factor * j), k])
    end
    coarse
end

function load_interior(path::String)
    jldopen(path, "r") do file
        nxy = Int(file["nx"])
        theta = Array{Float64, 3}(file["theta"])[2:(nxy + 1), 2:(nxy + 1), 2:(NZ + 1)]
        id_map = Array(file["id_map"])[2:(nxy + 1), 2:(nxy + 1), 2:(NZ + 1)]
        zfaces = Float64.(file["z_faces"])
        return (nxy=nxy, theta=theta, id_map=id_map, zfaces=zfaces)
    end
end

function copper_volume(data)
    dx = 1.2e-3 / data.nxy
    dz = diff(data.zfaces)
    sum(count(==(UInt8(1)), @view(data.id_map[:, :, k])) * dx^2 * dz[k] for k in 1:NZ)
end

function evaluate_pilot!(manifest, manifest_path::String, data_root::String, ids)
    results = Dict{String, Any}()
    passed = true
    for case_id in ids
        reference = load_interior(joinpath(run_directory(data_root, case_id, 480), "snapshot.jld2"))
        reference_tmax = maximum(reference.theta)
        reference_copper = copper_volume(reference)
        grid_results = Dict{String, Any}()
        for nxy in PILOT_GRIDS
            candidate = load_interior(joinpath(run_directory(data_root, case_id, nxy), "snapshot.jld2"))
            factor = 480 ÷ nxy
            reference_on_grid = factor == 1 ? reference.theta : block_average(reference.theta, factor)
            rise_denominator = norm(reference_on_grid .- AMBIENT_TEMPERATURE)
            rise_l2 = norm(candidate.theta .- reference_on_grid) / rise_denominator
            tmax_difference = abs(maximum(candidate.theta) - reference_tmax)
            copper_difference = abs(copper_volume(candidate) - reference_copper) / reference_copper
            grid_results[string(nxy)] = Dict(
                "rise_relative_l2" => rise_l2,
                "tmax_difference_K" => tmax_difference,
                "copper_volume_relative_difference" => copper_difference,
            )
            if nxy == FINAL_NXY
                passed &= rise_l2 <= 0.005 && tmax_difference <= 0.1 && copper_difference <= 0.05
            end
        end
        results[string(case_id)] = grid_results
    end
    manifest["pilot"]["results"] = results
    manifest["pilot"]["status"] = passed ? "passed" : "failed"
    manifest["pilot"]["evaluated_at"] = string(now())
    save_manifest(manifest_path, manifest)
    atomic_json(joinpath(data_root, "pilot", "grid_convergence.json"), manifest["pilot"])
    return passed
end

function run_pilot!(manifest, manifest_path::String, data_root::String, timeout_seconds::Int)
    ids = pilot_case_ids(manifest)
    manifest["pilot"]["case_ids"] = ids
    manifest["pilot"]["status"] = "running"
    save_manifest(manifest_path, manifest)
    failures = 0
    for case_id in ids, nxy in PILOT_GRIDS
        ok = run_one!(manifest, manifest_path, data_root, case_by_id(manifest, case_id), nxy, timeout_seconds)
        failures = ok ? 0 : failures + 1
        failures >= 3 && error("three consecutive pilot failures; stopping safely")
        ok || error("pilot case $case_id at $nxy failed; dataset was not started")
    end
    passed = evaluate_pilot!(manifest, manifest_path, data_root, ids)
    passed || error("240x240 grid did not pass the approved 480-grid convergence gates")
    println("Pilot passed all 240-vs-480 gates.")
end

function run_dataset!(manifest, manifest_path::String, data_root::String, timeout_seconds::Int)
    manifest["pilot"]["status"] == "passed" || error("pilot has not passed; refusing to run the 100-case dataset")
    manifest["status"] = "dataset_running"
    save_manifest(manifest_path, manifest)
    consecutive_failures = 0
    for case in manifest["cases"]
        ok = run_one!(manifest, manifest_path, data_root, case, FINAL_NXY, timeout_seconds)
        consecutive_failures = ok ? 0 : consecutive_failures + 1
        consecutive_failures >= 3 && error("three consecutive dataset failures; stopping safely")
    end
    successful = count(case -> begin
        key = run_key(case["case_id"], FINAL_NXY)
        haskey(manifest["runs"], key) && manifest["runs"][key]["status"] in ("success", "cached")
    end, manifest["cases"])
    manifest["status"] = successful == length(manifest["cases"]) ? "complete" : "incomplete"
    save_manifest(manifest_path, manifest)
    println("Dataset: $successful / $(length(manifest["cases"])) valid 240-grid cases.")
end

function main(args=ARGS)
    options = parse_options(args)
    data_root = options["data_root"]
    manifest, manifest_path = load_or_prepare(data_root)
    write_plan(data_root, manifest)
    println("Prepared $(length(manifest["cases"])) unique cases at $data_root")
    options["phase"] == "prepare" && return
    if options["phase"] in ("pilot", "all")
        run_pilot!(manifest, manifest_path, data_root, options["pilot_timeout"])
    end
    if options["phase"] in ("dataset", "all")
        run_dataset!(manifest, manifest_path, data_root, options["case_timeout"])
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
