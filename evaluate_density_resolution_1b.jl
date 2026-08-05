#!/usr/bin/env julia

# Analyze completed Experiment 1B master groups. Each group contains the same
# 16×16 master occupancy regenerated at 2×2/4×4/8×8/16×16.

using JLD2
using JSON
using LinearAlgebra
using Plots
using Printf
using Statistics

include(abspath("run_density_resolution_1b.jl"))
include(abspath("H2-rom/src/PODEngine/PODEngine.jl"))
using .PODEngine
include(abspath("H2-rom/src/ROMInterpolator/ROMInterpolator.jl"))
using .ROMInterpolator

const OUTPUT_DIR_1B = "plots/for_paper/01b_placement_resolution"
const RIC_THRESHOLD_1B = 0.9999
const RBF_EPSILON_EVAL_1B = 1.0
const RBF_LAMBDA_EVAL_1B = 1e-6

function successful_record(record)
    get(record, "status", "") in ("success", "cached")
end

function complete_master_ids(manifest)
    ids = sort(unique(Int(record["master_id"]) for record in manifest["cases"]))
    return filter(ids) do master_id
        records = filter(record -> record["master_id"] == master_id && successful_record(record), manifest["cases"])
        Set(Int(record["resolution"]) for record in records) == Set(RESOLUTIONS_1B)
    end
end

function case_record(manifest, master_id::Int, g::Int)
    matches = filter(
        record -> record["master_id"] == master_id && record["resolution"] == g && successful_record(record),
        manifest["cases"],
    )
    length(matches) == 1 || error("expected one successful record for master $master_id at g=$g")
    return only(matches)
end

function load_temperature_1b(record)
    path = normpath(String(record["snapshot_path"]))
    return JLD2.jldopen(path, "r") do file
        key = haskey(file, "theta") ? "theta" : (haskey(file, "temperature") ? "temperature" : "")
        isempty(key) && error("temperature missing from $path")
        Float64.(file[key])
    end
end

function layout_coordinates(config)
    points = expanded_layout(config)
    return [(point.x, point.y) for point in points]
end

function symmetric_chamfer_um(first_layout, second_layout)
    nearest_mean(source, target) = mean(
        minimum(hypot(source_point[1] - target_point[1], source_point[2] - target_point[2]) for target_point in target)
        for source_point in source
    )
    return 0.5(nearest_mean(first_layout, second_layout) + nearest_mean(second_layout, first_layout)) * 1e6
end

function write_namedtuple_tsv(path::String, rows)
    isempty(rows) && return
    open(path, "w") do io
        println(io, join(keys(first(rows)), '\t'))
        for row in rows
            println(io, join(values(row), '\t'))
        end
    end
end

function plot_master_geometry(master, base_config, output_dir::String)
    density_plots = Any[]
    layout_plots = Any[]
    layouts = Dict{Int, Any}()
    for g in RESOLUTIONS_1B
        mu, counts, _, block_means = coarsen_master_occupancy(master, g)
        config = build_resolution_config(base_config, g, mu, WORK_ROOT_1B)
        points = expanded_layout(config)
        layouts[g] = points
        annotations = [
            (i, j, text(string(counts[i, j]), min(9, 18 - g ÷ 2), :black))
            for i in 1:g for j in 1:g if counts[i, j] > 0
        ]
        p_density = heatmap(
            1:g,
            1:g,
            block_means';
            clims=(0.0, 1.0),
            color=:YlGnBu,
            aspect_ratio=:equal,
            xlabel="cell i",
            ylabel="cell j",
            title="$(g)×$(g) block mean",
            colorbar=g == 16,
        )
        annotate!(p_density, annotations)
        push!(density_plots, p_density)

        p_layout = scatter(
            [point.x * 1e3 for point in points],
            [point.y * 1e3 for point in points];
            xlims=(0.0, 1.2),
            ylims=(0.0, 1.2),
            aspect_ratio=:equal,
            markersize=4,
            markercolor=:orange,
            markerstrokecolor=:black,
            xlabel="X [mm]",
            ylabel="Y [mm]",
            title="$(g)×$(g) generated layout",
            legend=false,
        )
        push!(layout_plots, p_layout)
    end
    combined = plot(
        density_plots...,
        layout_plots...;
        layout=(2, 4),
        size=(1600, 780),
        plot_title="Experiment 1B: one 16×16 master, capacity-corrected aggregation, 16 TSVs",
    )
    savefig(combined, joinpath(output_dir, "matched_master_density_and_layouts.png"))
    return layouts
end

function physical_sensitivity(manifest, master_ids, masters, base_config, output_dir::String)
    rows = NamedTuple[]
    temperatures = Dict{Tuple{Int, Int}, Array{Float64, 3}}()
    for master_id in master_ids, g in RESOLUTIONS_1B
        temperatures[(master_id, g)] = load_temperature_1b(case_record(manifest, master_id, g))
    end

    for master_id in master_ids
        reference_temperature = temperatures[(master_id, 16)]
        reference_mu, _, _, _ = coarsen_master_occupancy(masters[master_id], 16)
        reference_config = build_resolution_config(base_config, 16, reference_mu, WORK_ROOT_1B)
        reference_layout = layout_coordinates(reference_config)
        for g in RESOLUTIONS_1B
            temperature = temperatures[(master_id, g)]
            mu, _, _, _ = coarsen_master_occupancy(masters[master_id], g)
            config = build_resolution_config(base_config, g, mu, WORK_ROOT_1B)
            layout = layout_coordinates(config)
            push!(rows, (
                master_id=master_id,
                resolution=g,
                geometry_chamfer_um=symmetric_chamfer_um(layout, reference_layout),
                field_l2_difference_percent=100norm(temperature - reference_temperature) / norm(reference_temperature),
                tmax_difference_K=abs(maximum(temperature) - maximum(reference_temperature)),
                temperature_max_K=maximum(temperature),
            ))
        end
    end
    write_namedtuple_tsv(joinpath(output_dir, "experiment_1b_physical_cases.tsv"), rows)

    summary_rows = NamedTuple[]
    for g in RESOLUTIONS_1B
        selected = filter(row -> row.resolution == g, rows)
        geometry = getfield.(selected, :geometry_chamfer_um)
        l2 = getfield.(selected, :field_l2_difference_percent)
        tmax = getfield.(selected, :tmax_difference_K)
        push!(summary_rows, (
            resolution=g,
            n_masters=length(selected),
            mean_geometry_chamfer_um=mean(geometry),
            max_geometry_chamfer_um=maximum(geometry),
            mean_field_l2_difference_percent=mean(l2),
            max_field_l2_difference_percent=maximum(l2),
            mean_tmax_difference_K=mean(tmax),
            max_tmax_difference_K=maximum(tmax),
        ))
    end
    write_namedtuple_tsv(joinpath(output_dir, "experiment_1b_physical_summary.tsv"), summary_rows)

    lower_resolutions = [2, 4, 8]
    p_geometry = plot(
        lower_resolutions,
        [only(filter(row -> row.resolution == g, summary_rows)).mean_geometry_chamfer_um for g in lower_resolutions];
        marker=:circle,
        linewidth=2,
        xlabel="Placement generation resolution G×G",
        ylabel="Symmetric layout distance [μm]",
        title="Geometry change from 16×16 reference",
        legend=false,
        xticks=RESOLUTIONS_1B,
    )
    p_temperature = plot(
        lower_resolutions,
        [only(filter(row -> row.resolution == g, summary_rows)).mean_field_l2_difference_percent for g in lower_resolutions];
        marker=:diamond,
        linewidth=2,
        xlabel="Placement generation resolution G×G",
        ylabel="FVM field difference [%]",
        title="Temperature-field change",
        label="mean L2",
        xticks=RESOLUTIONS_1B,
    )
    combined = plot(
        p_geometry,
        p_temperature;
        layout=(1, 2),
        size=(1100, 430),
        plot_title="Experiment 1B: physical sensitivity to placement-generation resolution",
    )
    savefig(combined, joinpath(output_dir, "physical_sensitivity_vs_resolution.png"))

    scatter_rows = filter(row -> row.resolution < 16, rows)
    correlation_plot = scatter(
        getfield.(scatter_rows, :geometry_chamfer_um),
        getfield.(scatter_rows, :field_l2_difference_percent);
        group=string.(getfield.(scatter_rows, :resolution)) .* "×" .* string.(getfield.(scatter_rows, :resolution)),
        xlabel="Symmetric layout distance from 16×16 [μm]",
        ylabel="FVM field difference [%]",
        title="Geometry displacement vs thermal-field change",
        legend_title="resolution",
    )
    savefig(correlation_plot, joinpath(output_dir, "geometry_vs_temperature_change.png"))

    representative_id = first(master_ids)
    slices = Matrix{Float64}[]
    for g in RESOLUTIONS_1B
        temperature = temperatures[(representative_id, g)]
        push!(slices, temperature[2:end-1, 2:end-1, 13]')
    end
    common_limits = extrema(vcat(vec.(slices)...))
    temperature_plots = [
        heatmap(
            slices[index];
            clims=common_limits,
            color=:thermal,
            aspect_ratio=:equal,
            title="$(g)×$(g) placement",
            xlabel="X cell",
            ylabel="Y cell",
            colorbar=index == length(RESOLUTIONS_1B),
        )
        for (index, g) in enumerate(RESOLUTIONS_1B)
    ]
    temperature_plot = plot(
        temperature_plots...;
        layout=(2, 2),
        size=(900, 800),
        plot_title="Experiment 1B: FVM temperature fields for matched master $representative_id [K]",
    )
    savefig(temperature_plot, joinpath(output_dir, "matched_master_fvm_temperatures.png"))
    return rows, summary_rows, temperatures
end

function rom_sensitivity(manifest, master_ids, temperatures, output_dir::String)
    length(master_ids) >= 10 || return NamedTuple[], NamedTuple[]
    n_train = max(2, floor(Int, 0.8length(master_ids)))
    train_ids = master_ids[1:n_train]
    holdout_ids = master_ids[n_train+1:end]
    isempty(holdout_ids) && return NamedTuple[], NamedTuple[]

    case_rows = NamedTuple[]
    summary_rows = NamedTuple[]
    for g in RESOLUTIONS_1B
        X = reduce(hcat, [vec(temperatures[(master_id, g)]) for master_id in master_ids])
        Mu = reduce(hcat, [Float64.(case_record(manifest, master_id, g)["mu"]) for master_id in master_ids])
        X_train = X[:, 1:n_train]
        Mu_train = Mu[:, 1:n_train]
        basis, _, coefficients, mean_field = PODEngine.compute_pod(X_train; ric_threshold=RIC_THRESHOLD_1B)
        interpolator = ROMInterpolator.RBFInterpolator(RBF_EPSILON_EVAL_1B)
        ROMInterpolator.fit!(interpolator, Mu_train, coefficients; lambda=RBF_LAMBDA_EVAL_1B)

        l2_errors = Float64[]
        tmax_errors = Float64[]
        for (local_index, master_id) in enumerate(holdout_ids)
            source_index = n_train + local_index
            prediction = ROMInterpolator.reconstruct_field(
                ROMInterpolator.predict(interpolator, Mu[:, source_index]),
                basis,
                mean_field,
            )
            truth = X[:, source_index]
            l2_percent = 100norm(prediction - truth) / norm(truth)
            tmax_error = abs(maximum(prediction) - maximum(truth))
            push!(l2_errors, l2_percent)
            push!(tmax_errors, tmax_error)
            push!(case_rows, (
                resolution=g,
                master_id=master_id,
                split="holdout",
                l2_percent=l2_percent,
                tmax_error_K=tmax_error,
                within_train_bounds=ROMInterpolator.is_reliable(interpolator, Mu[:, source_index]),
            ))
        end
        push!(summary_rows, (
            resolution=g,
            n_train=length(train_ids),
            n_holdout=length(holdout_ids),
            retained_modes=size(basis, 2),
            mean_l2_percent=mean(l2_errors),
            median_l2_percent=median(l2_errors),
            max_l2_percent=maximum(l2_errors),
            mean_tmax_error_K=mean(tmax_errors),
            median_tmax_error_K=median(tmax_errors),
            max_tmax_error_K=maximum(tmax_errors),
        ))
    end
    write_namedtuple_tsv(joinpath(output_dir, "experiment_1b_rom_cases.tsv"), case_rows)
    write_namedtuple_tsv(joinpath(output_dir, "experiment_1b_rom_summary.tsv"), summary_rows)

    resolutions = getfield.(summary_rows, :resolution)
    p_l2 = plot(
        resolutions,
        getfield.(summary_rows, :mean_l2_percent);
        marker=:circle,
        linewidth=2,
        xlabel="Placement generation resolution G×G",
        ylabel="ROM relative L2 error [%]",
        title="ROM error on matched-master holdout",
        label="mean",
        xticks=resolutions,
    )
    plot!(p_l2, resolutions, getfield.(summary_rows, :median_l2_percent); marker=:diamond, color=:black, label="median")
    p_tmax = plot(
        resolutions,
        getfield.(summary_rows, :mean_tmax_error_K);
        marker=:circle,
        linewidth=2,
        color=:darkorange,
        xlabel="Placement generation resolution G×G",
        ylabel="|ΔTmax| [K]",
        title="ROM Tmax error",
        label="mean",
        xticks=resolutions,
    )
    plot!(p_tmax, resolutions, getfield.(summary_rows, :median_tmax_error_K); marker=:diamond, color=:black, label="median")
    combined = plot(
        p_l2,
        p_tmax;
        layout=(1, 2),
        size=(1100, 430),
        plot_title="Experiment 1B: ROM performance after resolution-dependent FVM regeneration",
    )
    savefig(combined, joinpath(output_dir, "rom_accuracy_vs_placement_resolution.png"))
    return case_rows, summary_rows
end

function evaluate_experiment_1b(
    ;
    work_root::String=WORK_ROOT_1B,
    output_dir::String=OUTPUT_DIR_1B,
)
    manifest_path = joinpath(work_root, "manifest.json")
    isfile(manifest_path) || error("Experiment 1B manifest not found: $manifest_path")
    manifest = JSON.parsefile(manifest_path)
    master_ids = complete_master_ids(manifest)
    isempty(master_ids) && error("No complete four-resolution master groups are available")
    mkpath(output_dir)

    masters = generate_master_occupancies(
        Int(manifest["target_masters"]);
        n_tsv=Int(manifest["n_tsv"]),
        seed=Int(manifest["master_seed"]),
    )
    base_config = SnapshotGenerator.Runner.default_model_config()
    plot_master_geometry(masters[first(master_ids)], base_config, output_dir)
    physical_rows, physical_summary, temperatures =
        physical_sensitivity(manifest, master_ids, masters, base_config, output_dir)
    rom_rows, rom_summary = rom_sensitivity(manifest, master_ids, temperatures, output_dir)

    open(joinpath(output_dir, "README.md"), "w") do io
        println(io, "# Experiment 1B: placement-generation resolution")
        println(io)
        println(io, "- Complete matched master groups: $(length(master_ids)) ($(join(master_ids, ", "))).")
        println(io, "- Every master starts from a binary 16×16 occupancy with exactly 16 TSVs.")
        println(io, "- Coarser inputs use block aggregation followed by physical cell-capacity correction.")
        println(io, "- Every resolution regenerates the TSV coordinates and reruns the 240×240×30 FVM.")
        println(io, "- The 16×16 placement is the physical-sensitivity reference for each master.")
        if isempty(rom_summary)
            println(io, "- ROM evaluation is deferred until at least 10 complete masters exist.")
        else
            println(io, "- ROM split is identical across resolutions: first $(rom_summary[1].n_train) masters train, remaining $(rom_summary[1].n_holdout) holdout.")
        end
    end

    println("Experiment 1B analyzed: $(length(master_ids)) complete matched masters")
    println("Outputs: $(abspath(output_dir))")
    return physical_summary, rom_summary
end

if abspath(PROGRAM_FILE) == @__FILE__
    evaluate_experiment_1b()
end
