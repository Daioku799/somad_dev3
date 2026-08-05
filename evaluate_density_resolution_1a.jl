#!/usr/bin/env julia

# Experiment 1A: keep each physical TSV layout and FVM temperature field fixed,
# and change only the density-map resolution supplied to the ROM.

using JLD2
using JSON3
using LinearAlgebra
using Plots
using Printf
using Statistics

include(abspath("H2-main-ext/src/ConfigLoader/ConfigLoader.jl"))
using .ConfigLoader
include(abspath("H2-main-ext/src/ComponentGenerator/ComponentGenerator.jl"))
using .ComponentGenerator

include(abspath("H2-rom/src/DensityResolutionExperiments/DensityResolutionExperiments.jl"))
using .DensityResolutionExperiments
include(abspath("H2-rom/src/PODEngine/PODEngine.jl"))
using .PODEngine
include(abspath("H2-rom/src/ROMInterpolator/ROMInterpolator.jl"))
using .ROMInterpolator

const RESOLUTIONS_1A = [2, 4, 8, 16]
const TRAIN_FRACTION_1A = 0.8
const RIC_THRESHOLD_1A = 0.9999
const RBF_EPSILON_1A = 1.0
const RBF_LAMBDA_1A = 1e-6
const AMBIENT_TEMPERATURE_1A_K = 300.0
const OUTPUT_DIR_1A = "plots/for_paper/01a_rom_input_resolution_reconstructed"

function snapshot_temperature(snapshot_path::String)
    return JLD2.jldopen(snapshot_path, "r") do file
        if haskey(file, "temperature")
            Float64.(file["temperature"])
        elseif haskey(file, "theta")
            Float64.(file["theta"])
        else
            error("temperature field is missing from $snapshot_path")
        end
    end
end

function saved_case_layout(case_id::Int, manifest_mu::Vector{Float64})
    case_dir = joinpath("data", "work", "case_$case_id")
    config_path = joinpath(case_dir, "config.json")
    tsv_config_path = joinpath(case_dir, "tsv_config.json")
    isfile(config_path) || error("saved case config is missing: $config_path")
    isfile(tsv_config_path) || error("saved case TSV config is missing: $tsv_config_path")
    config = ConfigLoader.load_config(config_path, tsv_config_path)
    config.tsv.density === nothing && error("saved case $case_id has no density-map config")
    saved_mu = config.tsv.density.mu
    isapprox(saved_mu, manifest_mu; atol=1e-12, rtol=0.0) ||
        error("manifest/config mu mismatch for case $case_id")
    layout = ComponentGenerator.Layout.expand_coordinates(config.tsv, config.lx, config.ly)
    return layout, config
end

function load_experiment_1a_data(manifest_path::String)
    manifest = JSON3.read(read(manifest_path, String))
    cases = filter(case -> case.status == "success", manifest.cases)
    length(cases) >= 10 || error("Experiment 1A needs at least 10 successful snapshots")

    temperatures = Vector{Vector{Float64}}()
    shapes = Tuple{Int, Int, Int}[]
    case_ids = Int[]
    snapshot_ids = String[]
    encodings = Dict(g => Vector{Vector{Float64}}() for g in RESOLUTIONS_1A)
    layout_counts = Int[]
    n_limits = Int[]
    physical_domains = Tuple{Float64, Float64}[]
    selected_layout = nothing
    selected_encodings = Dict{Int, Vector{Float64}}()
    selected_counts = Dict{Int, Matrix{Int}}()

    for (index, case) in enumerate(cases)
        path = normpath(String(case.filepath))
        isfile(path) || error("snapshot does not exist: $path")
        temperature = snapshot_temperature(path)
        push!(temperatures, vec(temperature))
        push!(shapes, size(temperature))
        push!(case_ids, Int(case.id))

        metadata = JLD2.jldopen(path, "r") do file
            haskey(file, "metadata") ? file["metadata"] : Dict{String, Any}()
        end
        push!(snapshot_ids, haskey(metadata, "snapshot_id") ? string(metadata["snapshot_id"]) : "")

        mu = Float64.(case.mu)
        layout, case_config = saved_case_layout(Int(case.id), mu)
        push!(layout_counts, length(layout))
        n_limit = case_config.tsv.density.n_max
        n_limit > 0 || error("case $(case.id) has no positive global TSV limit")
        push!(n_limits, n_limit)
        push!(physical_domains, (case_config.lx, case_config.ly))

        for g in RESOLUTIONS_1A
            counts = count_layout(
                layout,
                g;
                lx=case_config.lx,
                ly=case_config.ly,
            )
            # Divide by one resolution-independent global limit. Unlike a
            # unit-sum histogram, this preserves the case-to-case TSV count.
            encoded_mu = vec(counts ./ n_limit)
            push!(encodings[g], encoded_mu)
            if index == 1
                selected_encodings[g] = encoded_mu
                selected_counts[g] = counts
            end
        end
        index == 1 && (selected_layout = layout)
    end

    length(unique(shapes)) == 1 || error("snapshot shapes are inconsistent: $(unique(shapes))")
    length(unique(snapshot_ids)) == length(snapshot_ids) || error("snapshot IDs are not unique")
    length(unique(n_limits)) == 1 || error("saved cases have inconsistent TSV limits: $(unique(n_limits))")
    length(unique(physical_domains)) == 1 || error("saved cases have inconsistent XY domains")

    X = reduce(hcat, temperatures)
    Mu = Dict(g => reduce(hcat, encodings[g]) for g in RESOLUTIONS_1A)
    return (
        X=X,
        Mu=Mu,
        shape=only(unique(shapes)),
        case_ids=case_ids,
        snapshot_ids=snapshot_ids,
        layout_counts=layout_counts,
        selected_layout=selected_layout,
        selected_encodings=selected_encodings,
        selected_counts=selected_counts,
        n_limit=only(unique(n_limits)),
        physical_domain=only(unique(physical_domains)),
    )
end

function plot_input_encodings(data, output_dir::String)
    layout = data.selected_layout
    x_mm = [point.x * 1e3 for point in layout]
    y_mm = [point.y * 1e3 for point in layout]
    p_layout = scatter(
        x_mm,
        y_mm;
        xlims=(0.0, 1.2),
        ylims=(0.0, 1.2),
        aspect_ratio=:equal,
        markersize=5,
        markercolor=:orange,
        markerstrokecolor=:black,
        xlabel="X [mm]",
        ylabel="Y [mm]",
        title="Saved physical layout\n($(length(layout)) TSVs)",
        legend=false,
    )

    encoding_plots = Any[p_layout]
    common_encoding_max = maximum(maximum(encoded) for encoded in Base.values(data.selected_encodings))
    for g in RESOLUTIONS_1A
        mu_matrix = reshape(data.selected_encodings[g], g, g)
        annotation_size = g >= 16 ? 5 : (g >= 8 ? 7 : 9)
        annotations = [
            (i, j, text(string(data.selected_counts[g][i, j]), annotation_size, :black))
            for i in 1:g for j in 1:g if data.selected_counts[g][i, j] > 0
        ]
        p = heatmap(
            1:g,
            1:g,
            mu_matrix';
            clims=(0.0, common_encoding_max),
            color=:YlGnBu,
            aspect_ratio=:equal,
            xlabel="cell i",
            ylabel="cell j",
            title="ROM input $(g)×$(g)\ncount / $(data.n_limit)",
            colorbar=false,
        )
        annotate!(p, annotations)
        push!(encoding_plots, p)
    end

    combined = plot(
        encoding_plots...;
        layout=(2, 3),
        size=(1350, 850),
        plot_title="Experiment 1A: saved geometry represented at four input resolutions",
    )
    savefig(combined, joinpath(output_dir, "same_geometry_input_encodings.png"))
end

function run_experiment_1a(; manifest_path::String="data/manifest.json", output_dir::String=OUTPUT_DIR_1A)
    mkpath(output_dir)
    data = load_experiment_1a_data(manifest_path)
    n_cases = size(data.X, 2)
    n_train = round(Int, TRAIN_FRACTION_1A * n_cases)
    train_indices = 1:n_train
    holdout_indices = n_train + 1:n_cases
    isempty(holdout_indices) && error("holdout split is empty")

    println("Experiment 1A: $n_train train / $(length(holdout_indices)) fixed holdout cases")
    println("FVM field shape: $(data.shape), identical fields reused across all resolutions")

    X_train = data.X[:, train_indices]
    X_holdout = data.X[:, holdout_indices]
    basis, singular_values, coefficients, mean_field =
        PODEngine.compute_pod(X_train; ric_threshold=RIC_THRESHOLD_1A)

    case_rows = NamedTuple[]
    summary_rows = NamedTuple[]
    predictions = Dict{Int, Matrix{Float64}}()

    for g in RESOLUTIONS_1A
        Mu = data.Mu[g]
        Mu_train = Mu[:, train_indices]
        Mu_holdout = Mu[:, holdout_indices]
        interpolator = ROMInterpolator.RBFInterpolator(RBF_EPSILON_1A)
        ROMInterpolator.fit!(interpolator, Mu_train, coefficients; lambda=RBF_LAMBDA_1A)

        predicted_fields = Matrix{Float64}(undef, size(X_holdout))
        l2_errors = Float64[]
        rise_l2_errors = Float64[]
        tmax_errors = Float64[]
        reliable_flags = Bool[]
        duplicate_flags = Bool[]
        reliable_count = 0
        for (local_index, source_index) in enumerate(holdout_indices)
            mu = Mu_holdout[:, local_index]
            reliable = ROMInterpolator.is_reliable(interpolator, mu)
            duplicates_train_input = any(
                isapprox(mu, Mu_train[:, train_index]; atol=1e-12, rtol=0.0)
                for train_index in axes(Mu_train, 2)
            )
            reliable_count += reliable
            push!(reliable_flags, reliable)
            push!(duplicate_flags, duplicates_train_input)
            predicted_coefficients = ROMInterpolator.predict(interpolator, mu)
            prediction = ROMInterpolator.reconstruct_field(predicted_coefficients, basis, mean_field)
            predicted_fields[:, local_index] = prediction
            truth = X_holdout[:, local_index]
            l2_percent = 100norm(prediction - truth) / norm(truth)
            rise_l2_percent = 100norm(prediction - truth) / norm(truth .- AMBIENT_TEMPERATURE_1A_K)
            tmax_error = abs(maximum(prediction) - maximum(truth))
            push!(l2_errors, l2_percent)
            push!(rise_l2_errors, rise_l2_percent)
            push!(tmax_errors, tmax_error)
            push!(case_rows, (
                resolution=g,
                case_id=data.case_ids[source_index],
                snapshot_id=data.snapshot_ids[source_index],
                l2_percent=l2_percent,
                rise_l2_percent=rise_l2_percent,
                tmax_error_K=tmax_error,
                within_train_bounds=reliable,
                duplicates_train_input=duplicates_train_input,
            ))
        end
        predictions[g] = predicted_fields
        push!(summary_rows, (
            resolution=g,
            input_dimension=g^2,
            mean_l2_percent=mean(l2_errors),
            median_l2_percent=median(l2_errors),
            std_l2_percent=std(l2_errors),
            max_l2_percent=maximum(l2_errors),
            mean_rise_l2_percent=mean(rise_l2_errors),
            median_rise_l2_percent=median(rise_l2_errors),
            std_rise_l2_percent=std(rise_l2_errors),
            max_rise_l2_percent=maximum(rise_l2_errors),
            mean_tmax_error_K=mean(tmax_errors),
            median_tmax_error_K=median(tmax_errors),
            std_tmax_error_K=std(tmax_errors),
            max_tmax_error_K=maximum(tmax_errors),
            in_bounds_mean_l2_percent=mean(l2_errors[reliable_flags]),
            in_bounds_mean_tmax_error_K=mean(tmax_errors[reliable_flags]),
            reliable_holdout_count=reliable_count,
            unique_train_input_count=length(unique([Tuple(Mu_train[:, index]) for index in axes(Mu_train, 2)])),
            duplicate_train_input_count=count(duplicate_flags),
        ))
        @printf(
            "  %2d×%-2d: mean L2 = %.5f%%, mean Tmax = %.5f K, in-bounds = %d/%d\n",
            g,
            g,
            mean(l2_errors),
            mean(tmax_errors),
            reliable_count,
            length(holdout_indices),
        )
    end

    open(joinpath(output_dir, "experiment_1a_summary.tsv"), "w") do io
        println(io, join(keys(first(summary_rows)), '\t'))
        for row in summary_rows
            println(io, join(values(row), '\t'))
        end
    end
    open(joinpath(output_dir, "experiment_1a_holdout_cases.tsv"), "w") do io
        println(io, join(keys(first(case_rows)), '\t'))
        for row in case_rows
            println(io, join(values(row), '\t'))
        end
    end
    open(joinpath(output_dir, "experiment_1a_split.tsv"), "w") do io
        println(io, "case_id\tsnapshot_id\tsplit")
        for index in eachindex(data.case_ids)
            split = index <= n_train ? "train" : "holdout"
            println(io, "$(data.case_ids[index])\t$(data.snapshot_ids[index])\t$split")
        end
    end

    resolutions = getfield.(summary_rows, :resolution)
    mean_l2 = getfield.(summary_rows, :mean_l2_percent)
    median_l2 = getfield.(summary_rows, :median_l2_percent)
    mean_rise_l2 = getfield.(summary_rows, :mean_rise_l2_percent)
    median_rise_l2 = getfield.(summary_rows, :median_rise_l2_percent)
    mean_tmax = getfield.(summary_rows, :mean_tmax_error_K)
    median_tmax = getfield.(summary_rows, :median_tmax_error_K)
    n_holdout = length(holdout_indices)
    jitter = collect(range(-0.16, 0.16; length=n_holdout))
    p_l2 = plot(
        resolutions,
        mean_l2;
        marker=:circle,
        linewidth=2,
        yscale=:log10,
        xlabel="ROM input resolution G×G",
        ylabel="Relative L2 error [%]",
        title="Fixed-geometry ROM error",
        label="mean",
        xticks=resolutions,
    )
    plot!(p_l2, resolutions, median_l2; marker=:diamond, linewidth=2, color=:black, label="median")
    p_tmax = plot(
        resolutions,
        mean_tmax;
        marker=:diamond,
        linewidth=2,
        color=:darkorange,
        yscale=:log10,
        xlabel="ROM input resolution G×G",
        ylabel="|ΔTmax| [K]",
        title="Fixed-geometry Tmax error",
        label="mean",
        xticks=resolutions,
    )
    plot!(p_tmax, resolutions, median_tmax; marker=:diamond, linewidth=2, color=:black, label="median")
    p_rise_l2 = plot(
        resolutions,
        mean_rise_l2;
        marker=:circle,
        linewidth=2,
        color=:seagreen,
        xlabel="ROM input resolution G×G",
        ylabel="Rise-relative L2 error [%]",
        title="Relative to T - 300 K",
        label="mean",
        xticks=resolutions,
    )
    plot!(p_rise_l2, resolutions, median_rise_l2; marker=:diamond, linewidth=2, color=:black, label="median")
    for g in RESOLUTIONS_1A
        rows = filter(row -> row.resolution == g, case_rows)
        for (index, row) in enumerate(rows)
            marker = row.duplicates_train_input ? :star5 : (row.within_train_bounds ? :circle : :xcross)
            l2_color = row.duplicates_train_input ? :black : :steelblue
            rise_color = row.duplicates_train_input ? :black : :seagreen
            tmax_color = row.duplicates_train_input ? :black : :darkorange
            scatter!(p_l2, [g + jitter[index]], [row.l2_percent]; marker=marker,
                markersize=4, color=l2_color, alpha=0.7, label=false)
            scatter!(p_rise_l2, [g + jitter[index]], [row.rise_l2_percent]; marker=marker,
                markersize=4, color=rise_color, alpha=0.7, label=false)
            scatter!(p_tmax, [g + jitter[index]], [row.tmax_error_K]; marker=marker,
                markersize=4, color=tmax_color, alpha=0.7, label=false)
        end
    end
    summary_plot = plot(
        p_l2,
        p_rise_l2,
        p_tmax;
        layout=(1, 3),
        size=(1500, 450),
        plot_title="Experiment 1A: fixed saved geometry; only ROM encoding changes",
    )
    savefig(summary_plot, joinpath(output_dir, "accuracy_vs_input_resolution.png"))

    plot_input_encodings(data, output_dir)

    representative_holdout = 1
    error_slices = Matrix{Float64}[]
    for g in RESOLUTIONS_1A
        error_field = reshape(
            abs.(predictions[g][:, representative_holdout] - X_holdout[:, representative_holdout]),
            data.shape,
        )
        k = clamp(13, 2, data.shape[3] - 1)
        push!(error_slices, error_field[2:end-1, 2:end-1, k]')
    end
    common_max = maximum(maximum, error_slices)
    error_plots = [
        heatmap(
            error_slices[index];
            clims=(0.0, common_max),
            color=:inferno,
            aspect_ratio=:equal,
            title="$(g)×$(g) input",
            xlabel="X cell",
            ylabel="Y cell",
            colorbar=index == length(RESOLUTIONS_1A),
        )
        for (index, g) in enumerate(RESOLUTIONS_1A)
    ]
    error_plot = plot(
        error_plots...;
        layout=(2, 2),
        size=(900, 800),
        plot_title="Experiment 1A: absolute error for fixed holdout case $(data.case_ids[first(holdout_indices)]) [K]",
    )
    savefig(error_plot, joinpath(output_dir, "fixed_geometry_error_fields.png"))

    open(joinpath(output_dir, "README.md"), "w") do io
        println(io, "# Experiment 1A: ROM input representation resolution")
        println(io)
        println(io, "- Physical layouts and FVM temperature fields are identical at every resolution.")
        println(io, "- Split: first $n_train successful manifest cases for training; remaining $(n_cases - n_train) cases for fixed holdout evaluation.")
        println(io, "- POD RIC threshold: $RIC_THRESHOLD_1A ($(size(basis, 2)) retained modes).")
        println(io, "- Gaussian RBF: epsilon=$RBF_EPSILON_1A, lambda=$RBF_LAMBDA_1A.")
        println(io, "- Physical layouts are reconstructed from each saved `data/work/case_<id>/` config, not from current defaults.")
        println(io, "- Saved layouts contain $(minimum(data.layout_counts))--$(maximum(data.layout_counts)) TSVs; the fixed global limit is $(data.n_limit).")
        println(io, "- Input features are each cell's TSV count divided by the resolution-independent global limit $(data.n_limit), preserving total-count information.")
        println(io, "- Crosses in the accuracy plot denote validation points outside the per-feature training bounds.")
        println(io, "- Stars denote validation inputs that exactly duplicate a training input after resolution-specific aggregation.")
        println(io, "- No FVM simulation was rerun for this experiment.")
    end

    println("Experiment 1A outputs: $(abspath(output_dir))")
    return summary_rows, case_rows
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_experiment_1a()
end
