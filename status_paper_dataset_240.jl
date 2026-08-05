#!/usr/bin/env julia

using Dates
using JSON
using Printf
using Statistics

const DEFAULT_ROOT = abspath("data/paper_240_v1")

function count_status(records, statuses)
    count(record -> get(record, "status", "") in statuses, records)
end

function format_duration(seconds)
    !isfinite(seconds) && return "unknown"
    hours = floor(Int, seconds / 3600)
    minutes = floor(Int, (seconds - 3600hours) / 60)
    return hours > 0 ? "$(hours)h $(minutes)m" : "$(minutes)m"
end

function main(args=ARGS)
    data_root = isempty(args) ? DEFAULT_ROOT : abspath(args[1])
    manifest_path = joinpath(data_root, "manifest.json")
    if !isfile(manifest_path)
        println("No manifest yet: $manifest_path")
        return
    end

    manifest = JSON.parsefile(manifest_path)
    runs = collect(values(get(manifest, "runs", Dict{String, Any}())))
    final_runs = filter(run -> get(run, "nxy", 0) == 240, runs)
    pilot_runs = filter(run -> get(run, "nxy", 0) != 240, runs)
    final_valid = count_status(final_runs, ("success", "cached"))
    pilot_valid_non240 = count_status(pilot_runs, ("success", "cached"))
    pilot_ids = get(manifest["pilot"], "case_ids", Any[])
    pilot_240_valid = count(case_id -> any(run ->
        get(run, "case_id", 0) == case_id && get(run, "nxy", 0) == 240 &&
        get(run, "status", "") in ("success", "cached"), final_runs), pilot_ids)
    pilot_valid = pilot_valid_non240 + pilot_240_valid
    failed = count_status(runs, ("failed", "timeout"))

    println("paper_240_v1")
    println("  overall:       ", get(manifest, "status", "unknown"))
    println("  pilot:         ", get(manifest["pilot"], "status", "unknown"),
        " (", pilot_valid, "/", 4length(pilot_ids), " grid runs valid)")
    println("  240 dataset:   ", final_valid, "/", length(manifest["cases"]), " cases valid")
    println("  failed/timeout:", failed)
    println("  manifest:      ", manifest_path)
    println("  updated:       ", get(manifest, "updated_at", "unknown"))

    current = get(manifest, "current", nothing)
    if current !== nothing
        started = try
            DateTime(current["started_at"])
        catch
            nothing
        end
        elapsed = started === nothing ? "unknown" : format_duration(Dates.value(now() - started) / 1000)
        println(@sprintf("  running:       case %03d, grid %d (elapsed %s)",
            current["case_id"], current["nxy"], elapsed))
    else
        println("  running:       none recorded")
    end

    completed_final_times = Float64[
        run["runtime_seconds"] for run in final_runs
        if get(run, "status", "") == "success" && get(run, "runtime_seconds", 0) > 0
    ]
    if !isempty(completed_final_times) && final_valid < length(manifest["cases"])
        remaining = length(manifest["cases"]) - final_valid
        println("  rough 240 ETA: ", format_duration(remaining * mean(completed_final_times)),
            " (mean of ", length(completed_final_times), " newly run cases)")
    end

    driver_log = joinpath(data_root, "driver.log")
    println("\nLive details:")
    println("  tail -f $driver_log")
    println("  tmux -S /tmp/somad_dev3_paper240.sock attach -t paper240")
    println("  detach tmux with Ctrl-b, then d")
end

main()
