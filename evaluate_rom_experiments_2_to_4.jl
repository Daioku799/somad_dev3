#!/usr/bin/env julia

# Re-evaluate Experiments 2--4 from the fixed 50-snapshot dataset.
# This script does not run FVM. It writes new, explicitly named artifacts and
# leaves the legacy plots in the same directories untouched.

using JLD2
using JSON3
using LinearAlgebra
using Plots
using Printf
using Statistics

include(abspath("H2-rom/src/PODEngine/PODEngine.jl"))
using .PODEngine
include(abspath("H2-rom/src/ROMInterpolator/ROMInterpolator.jl"))
using .ROMInterpolator

const MANIFEST_PATH = "data/manifest.json"
const TRAIN_COUNT = 40
const HOLDOUT_COUNT = 10
const AMBIENT_TEMPERATURE_K = 300.0
const RIC_THRESHOLD = 0.9999
const BASELINE_EPSILON = 1.0
const BASELINE_LAMBDA = 1e-6
const SNAPSHOT_COUNTS = [5, 10, 15, 20, 40]
const FIXED_MODE_COUNT_EXP2 = 4
const EPSILON_VALUES = [0.5, 1.0, 1.5, 2.0, 3.0]
const LAMBDA_VALUES = [1e-8, 1e-6, 1e-4, 1e-2]

const EXP2_DIR = "plots/for_paper/02_snapshot_count"
const EXP3_DIR = "plots/for_paper/03_pod_modes"
const EXP4_DIR = "plots/for_paper/04_rbf_parameters"

function snapshot_temperature(path::String)
    return JLD2.jldopen(path, "r") do file
        key = haskey(file, "temperature") ? "temperature" :
              (haskey(file, "theta") ? "theta" : "")
        isempty(key) && error("temperature field is missing from $path")
        Float64.(file[key])
    end
end

function snapshot_metadata(path::String)
    return JLD2.jldopen(path, "r") do file
        metadata = haskey(file, "metadata") ? file["metadata"] : Dict{String, Any}()
        return (
            nx=Int(file["nx"]),
            ny=Int(file["ny"]),
            nz=Int(file["nz"]),
            snapshot_id=haskey(metadata, "snapshot_id") ? string(metadata["snapshot_id"]) : "",
        )
    end
end

function load_fixed_dataset(manifest_path::String=MANIFEST_PATH)
    isfile(manifest_path) || error("manifest not found: $manifest_path")
    manifest = JSON3.read(read(manifest_path, String))
    cases = sort(
        collect(filter(case -> case.status == "success", manifest.cases));
        by=case -> Int(case.id),
    )
    length(cases) == TRAIN_COUNT + HOLDOUT_COUNT ||
        error("expected exactly 50 successful cases, found $(length(cases))")

    temperatures = Vector{Vector{Float64}}()
    parameters = Vector{Vector{Float64}}()
    shapes = Tuple{Int, Int, Int}[]
    physical_grids = Tuple{Int, Int, Int}[]
    case_ids = Int[]
    snapshot_ids = String[]

    for case in cases
        path = normpath(String(case.filepath))
        isfile(path) || error("snapshot does not exist: $path")
        temperature = snapshot_temperature(path)
        metadata = snapshot_metadata(path)
        mu = Float64.(case.mu)
        length(mu) == 16 || error("case $(case.id) has $(length(mu)) parameters, expected 16")
        all(isfinite, temperature) || error("case $(case.id) contains non-finite temperatures")

        push!(temperatures, vec(temperature))
        push!(parameters, mu)
        push!(shapes, size(temperature))
        push!(physical_grids, (metadata.nx, metadata.ny, metadata.nz))
        push!(case_ids, Int(case.id))
        push!(snapshot_ids, metadata.snapshot_id)
    end

    length(unique(shapes)) == 1 || error("inconsistent saved array shapes: $(unique(shapes))")
    length(unique(physical_grids)) == 1 || error("inconsistent physical grids: $(unique(physical_grids))")
    all(!isempty, snapshot_ids) || error("one or more snapshot IDs are missing")
    length(unique(snapshot_ids)) == length(snapshot_ids) || error("snapshot IDs are not unique")

    return (
        X=reduce(hcat, temperatures),
        Mu=reduce(hcat, parameters),
        case_ids=case_ids,
        snapshot_ids=snapshot_ids,
        shape=only(unique(shapes)),
        physical_grid=only(unique(physical_grids)),
        train_indices=1:TRAIN_COUNT,
        holdout_indices=(TRAIN_COUNT + 1):(TRAIN_COUNT + HOLDOUT_COUNT),
    )
end

function prediction_metrics(prediction, truth)
    residual = prediction - truth
    truth_rise = truth .- AMBIENT_TEMPERATURE_K
    rise_norm = norm(truth_rise)
    rise_norm > eps(Float64) || error("temperature-rise norm is zero")
    return (
        l2_percent=100norm(residual) / norm(truth),
        rise_l2_percent=100norm(residual) / rise_norm,
        tmax_error_K=abs(maximum(prediction) - maximum(truth)),
    )
end

function write_namedtuple_tsv(path::String, rows)
    isempty(rows) && error("refusing to write an empty TSV: $path")
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, join(keys(first(rows)), '\t'))
        for row in rows
            println(io, join(values(row), '\t'))
        end
    end
end

function metric_panel(case_rows, summary_rows, xfield::Symbol, metric::Symbol;
                      xlabel::String, ylabel::String, title::String,
                      color=:steelblue, logscale::Bool=false)
    xvalues = getfield.(summary_rows, xfield)
    means = getfield.(summary_rows, Symbol("mean_", metric))
    medians = getfield.(summary_rows, Symbol("median_", metric))
    panel = plot(
        xvalues,
        means;
        marker=:circle,
        linewidth=2,
        color=color,
        label="mean",
        xlabel=xlabel,
        ylabel=ylabel,
        title=title,
        xticks=xvalues,
        yscale=logscale ? :log10 : :identity,
    )
    plot!(panel, xvalues, medians; marker=:diamond, linewidth=1.5, color=:black, label="median")

    for x in xvalues
        selected = filter(row -> getfield(row, xfield) == x, case_rows)
        jitter = collect(range(-0.15, 0.15; length=length(selected)))
        for (index, row) in enumerate(selected)
            marker = row.within_train_bounds ? :circle : :xcross
            scatter!(
                panel,
                [x + jitter[index]],
                [getfield(row, metric)];
                marker=marker,
                color=color,
                alpha=0.75,
                markersize=4,
                label=false,
            )
        end
    end
    return panel
end

function evaluate_snapshot_count(data)
    mkpath(EXP2_DIR)
    X_holdout = data.X[:, data.holdout_indices]
    Mu_holdout = data.Mu[:, data.holdout_indices]
    case_rows = NamedTuple[]
    summary_rows = NamedTuple[]
    baseline_pod = nothing

    for nsnap in SNAPSHOT_COUNTS
        X_train = data.X[:, 1:nsnap]
        Mu_train = data.Mu[:, 1:nsnap]
        basis, singular_values, coefficients, mean_field =
            PODEngine.compute_pod(X_train; ric_threshold=RIC_THRESHOLD)
        interpolator = ROMInterpolator.RBFInterpolator(BASELINE_EPSILON)
        ROMInterpolator.fit!(interpolator, Mu_train, coefficients; lambda=BASELINE_LAMBDA)
        size(basis, 2) >= FIXED_MODE_COUNT_EXP2 || error("insufficient modes for fixed-mode control")
        fixed_basis = basis[:, 1:FIXED_MODE_COUNT_EXP2]
        fixed_interpolator = ROMInterpolator.RBFInterpolator(BASELINE_EPSILON)
        ROMInterpolator.fit!(
            fixed_interpolator,
            Mu_train,
            coefficients[1:FIXED_MODE_COUNT_EXP2, :];
            lambda=BASELINE_LAMBDA,
        )

        l2_values = Float64[]
        rise_values = Float64[]
        tmax_values = Float64[]
        fixed_l2_values = Float64[]
        fixed_rise_values = Float64[]
        fixed_tmax_values = Float64[]
        reliable_flags = Bool[]
        for local_index in axes(X_holdout, 2)
            source_index = first(data.holdout_indices) + local_index - 1
            mu = Mu_holdout[:, local_index]
            prediction = ROMInterpolator.reconstruct_field(
                ROMInterpolator.predict(interpolator, mu), basis, mean_field
            )
            metrics = prediction_metrics(prediction, X_holdout[:, local_index])
            fixed_prediction = ROMInterpolator.reconstruct_field(
                ROMInterpolator.predict(fixed_interpolator, mu), fixed_basis, mean_field
            )
            fixed_metrics = prediction_metrics(fixed_prediction, X_holdout[:, local_index])
            reliable = ROMInterpolator.is_reliable(interpolator, mu)
            push!(l2_values, metrics.l2_percent)
            push!(rise_values, metrics.rise_l2_percent)
            push!(tmax_values, metrics.tmax_error_K)
            push!(fixed_l2_values, fixed_metrics.l2_percent)
            push!(fixed_rise_values, fixed_metrics.rise_l2_percent)
            push!(fixed_tmax_values, fixed_metrics.tmax_error_K)
            push!(reliable_flags, reliable)
            push!(case_rows, (
                nsnap=nsnap,
                case_id=data.case_ids[source_index],
                snapshot_id=data.snapshot_ids[source_index],
                l2_percent=metrics.l2_percent,
                rise_l2_percent=metrics.rise_l2_percent,
                tmax_error_K=metrics.tmax_error_K,
                fixed4_l2_percent=fixed_metrics.l2_percent,
                fixed4_rise_l2_percent=fixed_metrics.rise_l2_percent,
                fixed4_tmax_error_K=fixed_metrics.tmax_error_K,
                within_train_bounds=reliable,
            ))
        end

        push!(summary_rows, (
            nsnap=nsnap,
            n_holdout=length(data.holdout_indices),
            retained_modes=size(basis, 2),
            mean_l2_percent=mean(l2_values),
            median_l2_percent=median(l2_values),
            std_l2_percent=std(l2_values),
            max_l2_percent=maximum(l2_values),
            mean_rise_l2_percent=mean(rise_values),
            median_rise_l2_percent=median(rise_values),
            std_rise_l2_percent=std(rise_values),
            max_rise_l2_percent=maximum(rise_values),
            mean_tmax_error_K=mean(tmax_values),
            median_tmax_error_K=median(tmax_values),
            std_tmax_error_K=std(tmax_values),
            max_tmax_error_K=maximum(tmax_values),
            mean_fixed4_l2_percent=mean(fixed_l2_values),
            mean_fixed4_rise_l2_percent=mean(fixed_rise_values),
            mean_fixed4_tmax_error_K=mean(fixed_tmax_values),
            in_bounds_holdout_count=count(reliable_flags),
        ))
        nsnap == TRAIN_COUNT && (baseline_pod = (basis, singular_values, coefficients, mean_field))
    end

    write_namedtuple_tsv(joinpath(EXP2_DIR, "experiment_2_holdout_cases.tsv"), case_rows)
    write_namedtuple_tsv(joinpath(EXP2_DIR, "experiment_2_summary.tsv"), summary_rows)

    p_l2 = metric_panel(case_rows, summary_rows, :nsnap, :l2_percent;
        xlabel="Training snapshots", ylabel="Relative L2 error [%]",
        title="Absolute-temperature L2", color=:steelblue)
    p_rise = metric_panel(case_rows, summary_rows, :nsnap, :rise_l2_percent;
        xlabel="Training snapshots", ylabel="Rise-relative L2 error [%]",
        title="L2 relative to T - 300 K", color=:seagreen)
    p_tmax = metric_panel(case_rows, summary_rows, :nsnap, :tmax_error_K;
        xlabel="Training snapshots", ylabel="|ΔTmax| [K]",
        title="Maximum-temperature error", color=:darkorange)
    combined = plot(
        p_l2, p_rise, p_tmax;
        layout=(1, 3), size=(1500, 450),
        plot_title="Experiment 2: fixed holdout performance vs training-snapshot count",
    )
    savefig(combined, joinpath(EXP2_DIR, "experiment_2_accuracy_metrics.png"))

    xvalues = getfield.(summary_rows, :nsnap)
    p_modes = plot(xvalues, getfield.(summary_rows, :retained_modes);
        marker=:circle, linewidth=2, xlabel="Training snapshots", ylabel="Retained POD modes",
        title="RIC ≥ $RIC_THRESHOLD", xticks=xvalues, legend=false)
    p_coverage = bar(xvalues, getfield.(summary_rows, :in_bounds_holdout_count);
        xlabel="Training snapshots", ylabel="Holdout cases within bounds",
        title="Per-feature training-range coverage", xticks=xvalues,
        ylims=(0, HOLDOUT_COUNT + 0.5), legend=false, color=:slateblue)
    diagnostics = plot(p_modes, p_coverage; layout=(1, 2), size=(1050, 420),
        plot_title="Experiment 2: model complexity and holdout coverage")
    savefig(diagnostics, joinpath(EXP2_DIR, "experiment_2_modes_and_coverage.png"))

    function auto_fixed_panel(auto_field::Symbol, fixed_field::Symbol, ylabel::String, title::String, color)
        panel = plot(xvalues, getfield.(summary_rows, auto_field); marker=:circle, linewidth=2,
            color=color, label="automatic k (RIC)", xlabel="Training snapshots", ylabel=ylabel,
            title=title, xticks=xvalues)
        plot!(panel, xvalues, getfield.(summary_rows, fixed_field); marker=:diamond, linewidth=2,
            color=:black, label="fixed k=$FIXED_MODE_COUNT_EXP2")
        return panel
    end
    p_fixed_l2 = auto_fixed_panel(:mean_l2_percent, :mean_fixed4_l2_percent,
        "Mean relative L2 error [%]", "Absolute-temperature L2", :steelblue)
    p_fixed_rise = auto_fixed_panel(:mean_rise_l2_percent, :mean_fixed4_rise_l2_percent,
        "Mean rise-relative L2 [%]", "Temperature-rise L2", :seagreen)
    p_fixed_tmax = auto_fixed_panel(:mean_tmax_error_K, :mean_fixed4_tmax_error_K,
        "Mean |ΔTmax| [K]", "Maximum-temperature error", :darkorange)
    fixed_comparison = plot(p_fixed_l2, p_fixed_rise, p_fixed_tmax; layout=(1, 3), size=(1500, 440),
        plot_title="Experiment 2: snapshot-count effect with POD complexity controlled")
    savefig(fixed_comparison, joinpath(EXP2_DIR, "experiment_2_auto_vs_fixed4_modes.png"))

    open(joinpath(EXP2_DIR, "README_REEVALUATED.md"), "w") do io
        println(io, "# Experiment 2: training-snapshot count")
        println(io)
        println(io, "- Source dataset: 50 successful saved FVM snapshots.")
        println(io, "- Fixed holdout: cases 41--50; training subsets are nested prefixes of cases 1--40.")
        println(io, "- Counts compared: $(join(SNAPSHOT_COUNTS, ", ")).")
        println(io, "- POD RIC threshold: $RIC_THRESHOLD; Gaussian RBF epsilon=$BASELINE_EPSILON, lambda=$BASELINE_LAMBDA.")
        println(io, "- Crosses in the plots denote holdout points outside the per-feature training bounds.")
        println(io, "- This is a single deterministic subset path, not a repeated-subset uncertainty study.")
        println(io, "- A fixed-k=4 control is provided to separate snapshot-count effects from the automatic increase in retained POD modes.")
    end
    return summary_rows, case_rows, baseline_pod
end

function evaluate_pod_modes(data, baseline_pod)
    mkpath(EXP3_DIR)
    basis_full, singular_values, coefficients_full, mean_field = baseline_pod
    max_modes = size(basis_full, 2)
    mode_counts = sort(unique(min.(max_modes, [1, 2, 3, 5, 8, 10, 15, 20, 25, 30, 35, max_modes])))
    ric = cumsum(singular_values .^ 2) ./ sum(singular_values .^ 2)
    X_train = data.X[:, data.train_indices]
    Mu_train = data.Mu[:, data.train_indices]
    X_holdout = data.X[:, data.holdout_indices]
    Mu_holdout = data.Mu[:, data.holdout_indices]
    case_rows = NamedTuple[]
    summary_rows = NamedTuple[]

    for modes in mode_counts
        basis = basis_full[:, 1:modes]
        coefficients = coefficients_full[1:modes, :]
        interpolator = ROMInterpolator.RBFInterpolator(BASELINE_EPSILON)
        ROMInterpolator.fit!(interpolator, Mu_train, coefficients; lambda=BASELINE_LAMBDA)

        combined_l2 = Float64[]
        combined_rise = Float64[]
        combined_tmax = Float64[]
        projection_l2 = Float64[]
        projection_rise = Float64[]
        reliable_flags = Bool[]
        for local_index in axes(X_holdout, 2)
            source_index = first(data.holdout_indices) + local_index - 1
            truth = X_holdout[:, local_index]
            mu = Mu_holdout[:, local_index]
            prediction = ROMInterpolator.reconstruct_field(
                ROMInterpolator.predict(interpolator, mu), basis, mean_field
            )
            projection = mean_field + basis * (basis' * (truth - mean_field))
            total_metrics = prediction_metrics(prediction, truth)
            projection_metrics = prediction_metrics(projection, truth)
            reliable = ROMInterpolator.is_reliable(interpolator, mu)
            push!(combined_l2, total_metrics.l2_percent)
            push!(combined_rise, total_metrics.rise_l2_percent)
            push!(combined_tmax, total_metrics.tmax_error_K)
            push!(projection_l2, projection_metrics.l2_percent)
            push!(projection_rise, projection_metrics.rise_l2_percent)
            push!(reliable_flags, reliable)
            push!(case_rows, (
                modes=modes,
                case_id=data.case_ids[source_index],
                snapshot_id=data.snapshot_ids[source_index],
                l2_percent=total_metrics.l2_percent,
                rise_l2_percent=total_metrics.rise_l2_percent,
                tmax_error_K=total_metrics.tmax_error_K,
                projection_l2_percent=projection_metrics.l2_percent,
                projection_rise_l2_percent=projection_metrics.rise_l2_percent,
                within_train_bounds=reliable,
            ))
        end

        push!(summary_rows, (
            modes=modes,
            n_holdout=length(data.holdout_indices),
            ric=ric[modes],
            mean_l2_percent=mean(combined_l2),
            median_l2_percent=median(combined_l2),
            std_l2_percent=std(combined_l2),
            max_l2_percent=maximum(combined_l2),
            mean_rise_l2_percent=mean(combined_rise),
            median_rise_l2_percent=median(combined_rise),
            std_rise_l2_percent=std(combined_rise),
            max_rise_l2_percent=maximum(combined_rise),
            mean_tmax_error_K=mean(combined_tmax),
            median_tmax_error_K=median(combined_tmax),
            std_tmax_error_K=std(combined_tmax),
            max_tmax_error_K=maximum(combined_tmax),
            mean_projection_l2_percent=mean(projection_l2),
            mean_projection_rise_l2_percent=mean(projection_rise),
            in_bounds_holdout_count=count(reliable_flags),
        ))
    end

    write_namedtuple_tsv(joinpath(EXP3_DIR, "experiment_3_holdout_cases.tsv"), case_rows)
    write_namedtuple_tsv(joinpath(EXP3_DIR, "experiment_3_summary.tsv"), summary_rows)

    p_l2 = metric_panel(case_rows, summary_rows, :modes, :l2_percent;
        xlabel="Retained POD modes", ylabel="Relative L2 error [%]",
        title="Absolute-temperature L2", color=:steelblue)
    p_rise = metric_panel(case_rows, summary_rows, :modes, :rise_l2_percent;
        xlabel="Retained POD modes", ylabel="Rise-relative L2 error [%]",
        title="L2 relative to T - 300 K", color=:seagreen)
    p_tmax = metric_panel(case_rows, summary_rows, :modes, :tmax_error_K;
        xlabel="Retained POD modes", ylabel="|ΔTmax| [K]",
        title="Maximum-temperature error", color=:darkorange)
    accuracy = plot(p_l2, p_rise, p_tmax; layout=(1, 3), size=(1500, 450),
        plot_title="Experiment 3: fixed-holdout performance vs retained POD modes")
    savefig(accuracy, joinpath(EXP3_DIR, "experiment_3_accuracy_metrics.png"))

    p_decomp_l2 = plot(mode_counts, getfield.(summary_rows, :mean_l2_percent);
        marker=:circle, linewidth=2, label="POD + RBF", xlabel="Retained POD modes",
        ylabel="Mean relative L2 error [%]", title="Absolute-temperature error", xticks=mode_counts)
    plot!(p_decomp_l2, mode_counts, getfield.(summary_rows, :mean_projection_l2_percent);
        marker=:diamond, linewidth=2, label="POD projection lower bound", color=:black)
    p_decomp_rise = plot(mode_counts, getfield.(summary_rows, :mean_rise_l2_percent);
        marker=:circle, linewidth=2, label="POD + RBF", xlabel="Retained POD modes",
        ylabel="Mean rise-relative L2 error [%]", title="Temperature-rise error", xticks=mode_counts,
        color=:seagreen)
    plot!(p_decomp_rise, mode_counts, getfield.(summary_rows, :mean_projection_rise_l2_percent);
        marker=:diamond, linewidth=2, label="POD projection lower bound", color=:black)
    decomposition = plot(p_decomp_l2, p_decomp_rise; layout=(1, 2), size=(1100, 430),
        plot_title="Experiment 3: POD truncation error vs RBF-interpolation error")
    savefig(decomposition, joinpath(EXP3_DIR, "experiment_3_projection_vs_rbf.png"))

    p_singular = plot(1:length(singular_values), singular_values;
        marker=:circle, yscale=:log10, xlabel="POD mode index", ylabel="Singular value",
        title="Singular-value decay", legend=false)
    p_ric = plot(mode_counts, getfield.(summary_rows, :ric);
        marker=:square, linewidth=2, xlabel="Retained POD modes", ylabel="RIC",
        title="RIC at evaluated mode counts", ylims=(0.0, 1.005), xticks=mode_counts,
        legend=false, color=:firebrick)
    svd_ric = plot(p_singular, p_ric; layout=(1, 2), size=(1100, 430),
        plot_title="Experiment 3: POD spectrum and retained information")
    savefig(svd_ric, joinpath(EXP3_DIR, "experiment_3_svd_and_ric.png"))

    open(joinpath(EXP3_DIR, "README_REEVALUATED.md"), "w") do io
        println(io, "# Experiment 3: retained POD modes")
        println(io)
        println(io, "- Train/holdout split: cases 1--40 / 41--50.")
        println(io, "- Evaluated mode counts: $(join(mode_counts, ", ")).")
        println(io, "- Gaussian RBF epsilon=$BASELINE_EPSILON, lambda=$BASELINE_LAMBDA.")
        println(io, "- The POD projection curve uses each holdout truth field's exact projection and is a lower bound for this basis.")
        println(io, "- The gap between POD+RBF and projection curves indicates coefficient-interpolation error.")
    end
    return summary_rows, case_rows
end

function pareto_flags(rows)
    return [
        !any(
            (other.mean_l2_percent <= row.mean_l2_percent &&
             other.mean_tmax_error_K <= row.mean_tmax_error_K) &&
            (other.mean_l2_percent < row.mean_l2_percent ||
             other.mean_tmax_error_K < row.mean_tmax_error_K)
            for other in rows
        )
        for row in rows
    ]
end

function annotated_heatmap(values, title::String, colorbar_title::String, format::String)
    number_format = Printf.Format(format)
    panel = heatmap(
        1:length(EPSILON_VALUES),
        1:length(LAMBDA_VALUES),
        values;
        xticks=(1:length(EPSILON_VALUES), string.(EPSILON_VALUES)),
        yticks=(1:length(LAMBDA_VALUES), string.(LAMBDA_VALUES)),
        xlabel="Gaussian RBF epsilon",
        ylabel="Regularization lambda",
        title=title,
        color=:viridis,
    )
    threshold = (minimum(values) + maximum(values)) / 2
    for row in axes(values, 1), column in axes(values, 2)
        color = values[row, column] > threshold ? :white : :black
        annotate!(panel, column, row, text(Printf.format(number_format, values[row, column]), 8, color))
    end
    return panel
end

function evaluate_rbf_parameters(data, baseline_pod)
    mkpath(EXP4_DIR)
    basis, _, coefficients, mean_field = baseline_pod
    Mu_train = data.Mu[:, data.train_indices]
    X_holdout = data.X[:, data.holdout_indices]
    Mu_holdout = data.Mu[:, data.holdout_indices]
    case_rows = NamedTuple[]
    summary_rows = NamedTuple[]

    for epsilon in EPSILON_VALUES, lambda in LAMBDA_VALUES
        interpolator = ROMInterpolator.RBFInterpolator(epsilon)
        ROMInterpolator.fit!(interpolator, Mu_train, coefficients; lambda=lambda)
        l2_values = Float64[]
        rise_values = Float64[]
        tmax_values = Float64[]
        reliable_flags = Bool[]
        for local_index in axes(X_holdout, 2)
            source_index = first(data.holdout_indices) + local_index - 1
            mu = Mu_holdout[:, local_index]
            prediction = ROMInterpolator.reconstruct_field(
                ROMInterpolator.predict(interpolator, mu), basis, mean_field
            )
            metrics = prediction_metrics(prediction, X_holdout[:, local_index])
            reliable = ROMInterpolator.is_reliable(interpolator, mu)
            push!(l2_values, metrics.l2_percent)
            push!(rise_values, metrics.rise_l2_percent)
            push!(tmax_values, metrics.tmax_error_K)
            push!(reliable_flags, reliable)
            push!(case_rows, (
                epsilon=epsilon,
                lambda=lambda,
                case_id=data.case_ids[source_index],
                snapshot_id=data.snapshot_ids[source_index],
                l2_percent=metrics.l2_percent,
                rise_l2_percent=metrics.rise_l2_percent,
                tmax_error_K=metrics.tmax_error_K,
                within_train_bounds=reliable,
            ))
        end
        push!(summary_rows, (
            epsilon=epsilon,
            lambda=lambda,
            n_holdout=length(data.holdout_indices),
            retained_modes=size(basis, 2),
            mean_l2_percent=mean(l2_values),
            median_l2_percent=median(l2_values),
            std_l2_percent=std(l2_values),
            max_l2_percent=maximum(l2_values),
            mean_rise_l2_percent=mean(rise_values),
            median_rise_l2_percent=median(rise_values),
            std_rise_l2_percent=std(rise_values),
            max_rise_l2_percent=maximum(rise_values),
            mean_tmax_error_K=mean(tmax_values),
            median_tmax_error_K=median(tmax_values),
            std_tmax_error_K=std(tmax_values),
            max_tmax_error_K=maximum(tmax_values),
            in_bounds_holdout_count=count(reliable_flags),
        ))
    end

    flags = pareto_flags(summary_rows)
    summary_with_flags = [merge(row, (pareto=flags[index],)) for (index, row) in enumerate(summary_rows)]
    write_namedtuple_tsv(joinpath(EXP4_DIR, "experiment_4_holdout_cases.tsv"), case_rows)
    write_namedtuple_tsv(joinpath(EXP4_DIR, "experiment_4_summary.tsv"), summary_with_flags)

    l2_matrix = [
        only(filter(row -> row.epsilon == epsilon && row.lambda == lambda, summary_rows)).mean_l2_percent
        for lambda in LAMBDA_VALUES, epsilon in EPSILON_VALUES
    ]
    rise_matrix = [
        only(filter(row -> row.epsilon == epsilon && row.lambda == lambda, summary_rows)).mean_rise_l2_percent
        for lambda in LAMBDA_VALUES, epsilon in EPSILON_VALUES
    ]
    tmax_matrix = [
        only(filter(row -> row.epsilon == epsilon && row.lambda == lambda, summary_rows)).mean_tmax_error_K
        for lambda in LAMBDA_VALUES, epsilon in EPSILON_VALUES
    ]

    p_l2 = annotated_heatmap(l2_matrix, "Absolute-temperature relative L2", "mean [%]", "%.4f")
    p_rise = annotated_heatmap(rise_matrix, "Temperature-rise relative L2", "mean [%]", "%.2f")
    p_tmax = annotated_heatmap(tmax_matrix, "Maximum-temperature error", "mean [K]", "%.3f")
    heatmaps = plot(p_l2, p_rise, p_tmax; layout=(1, 3), size=(1700, 480),
        plot_title="Experiment 4: Gaussian RBF epsilon/lambda sensitivity (fixed holdout)")
    savefig(heatmaps, joinpath(EXP4_DIR, "experiment_4_parameter_heatmaps.png"))

    p_pareto = scatter(
        getfield.(summary_rows, :mean_l2_percent),
        getfield.(summary_rows, :mean_tmax_error_K);
        color=:gray65, markerstrokecolor=:gray35, markersize=6,
        xlabel="Mean relative L2 error [%]", ylabel="Mean |ΔTmax| [K]",
        title="Accuracy trade-off", label="all settings",
        xlims=(minimum(getfield.(summary_rows, :mean_l2_percent)) * 0.92,
               maximum(getfield.(summary_rows, :mean_l2_percent)) * 1.045),
    )
    frontier = sort(summary_rows[flags]; by=row -> row.mean_l2_percent)
    plot!(p_pareto, getfield.(frontier, :mean_l2_percent), getfield.(frontier, :mean_tmax_error_K);
        marker=:circle, linewidth=2, color=:seagreen, label="Pareto frontier")
    baseline = only(filter(row -> row.epsilon == BASELINE_EPSILON && row.lambda == BASELINE_LAMBDA, summary_rows))
    best_l2 = summary_rows[argmin(getfield.(summary_rows, :mean_l2_percent))]
    best_tmax = summary_rows[argmin(getfield.(summary_rows, :mean_tmax_error_K))]
    special = [(baseline, :star5, :black, "baseline"),
               (best_l2, :diamond, :royalblue, "best L2"),
               (best_tmax, :utriangle, :darkorange, "best Tmax")]
    for (row, marker, color, label) in special
        scatter!(p_pareto, [row.mean_l2_percent], [row.mean_tmax_error_K];
            marker=marker, color=color, markersize=9, label=label)
        annotate!(p_pareto, row.mean_l2_percent, row.mean_tmax_error_K,
            text(@sprintf("  ε=%.1f, λ=%.0e", row.epsilon, row.lambda), 8, :left))
    end
    savefig(p_pareto, joinpath(EXP4_DIR, "experiment_4_l2_tmax_pareto.png"))

    representative_conditions = [
        ("baseline", baseline),
        ("best L2", best_l2),
        ("best Tmax", best_tmax),
    ]
    function representative_case_panel(metric::Symbol, ylabel::String, title::String, color)
        labels = first.(representative_conditions)
        selected_by_condition = [
            sort(
                filter(
                    case -> case.epsilon == row.epsilon && case.lambda == row.lambda,
                    case_rows,
                );
                by=case -> case.case_id,
            )
            for (_, row) in representative_conditions
        ]
        panel = plot(; xlabel="Selected RBF condition", ylabel=ylabel, title=title,
            xticks=(1:length(labels), labels), legend=:topright)
        for case_index in eachindex(first(selected_by_condition))
            values = [getfield(selected[case_index], metric) for selected in selected_by_condition]
            plot!(panel, 1:length(labels), values; color=:gray70, alpha=0.55, linewidth=1, label=false)
            for condition_index in eachindex(labels)
                case = selected_by_condition[condition_index][case_index]
                marker = case.within_train_bounds ? :circle : :xcross
                scatter!(panel, [condition_index], [values[condition_index]];
                    marker=marker, color=color, alpha=0.65, markersize=4, label=false)
            end
        end
        means = [mean(getfield.(selected, metric)) for selected in selected_by_condition]
        medians = [median(getfield.(selected, metric)) for selected in selected_by_condition]
        plot!(panel, 1:length(labels), means; marker=:circle, color=color,
            linewidth=3, label="mean")
        plot!(panel, 1:length(labels), medians; marker=:diamond, color=:black,
            linewidth=2, label="median")
        return panel
    end
    p_cases_l2 = representative_case_panel(:l2_percent, "Relative L2 error [%]",
        "Absolute-temperature L2", :steelblue)
    p_cases_rise = representative_case_panel(:rise_l2_percent, "Rise-relative L2 [%]",
        "Temperature-rise L2", :seagreen)
    p_cases_tmax = representative_case_panel(:tmax_error_K, "|ΔTmax| [K]",
        "Maximum-temperature error", :darkorange)
    case_comparison = plot(p_cases_l2, p_cases_rise, p_cases_tmax;
        layout=(1, 3), size=(1500, 450),
        plot_title="Experiment 4: paired validation cases for three representative settings")
    savefig(case_comparison, joinpath(EXP4_DIR, "experiment_4_representative_case_comparison.png"))

    open(joinpath(EXP4_DIR, "README.md"), "w") do io
        println(io, "# Experiment 4: Gaussian RBF parameter sensitivity")
        println(io)
        println(io, "- This is an epsilon/lambda sweep for one Gaussian kernel, not a comparison of kernel families.")
        println(io, "- Train/holdout split: cases 1--40 / 41--50; retained POD modes: $(size(basis, 2)).")
        println(io, "- Epsilon values: $(join(EPSILON_VALUES, ", ")); lambda values: $(join(LAMBDA_VALUES, ", ")).")
        println(io, "- Baseline: epsilon=$BASELINE_EPSILON, lambda=$BASELINE_LAMBDA.")
        println(io, @sprintf("- Best mean L2: epsilon=%.1f, lambda=%.0e (%.5f%%).", best_l2.epsilon, best_l2.lambda, best_l2.mean_l2_percent))
        println(io, @sprintf("- Best mean Tmax: epsilon=%.1f, lambda=%.0e (%.5f K).", best_tmax.epsilon, best_tmax.lambda, best_tmax.mean_tmax_error_K))
        println(io, "- Parameter selection must name its objective because the L2 and Tmax optima differ.")
        println(io, "- The paired-case plot compares the baseline, L2-optimal, and Tmax-optimal settings; crosses are outside the per-feature train range.")
    end
    return summary_with_flags, case_rows
end

function write_split_and_dataset_metadata(data)
    rows = [
        (
            case_id=data.case_ids[index],
            snapshot_id=data.snapshot_ids[index],
            split=index <= TRAIN_COUNT ? "train" : "holdout",
        )
        for index in eachindex(data.case_ids)
    ]
    write_namedtuple_tsv("plots/for_paper/experiments_2_to_4_split.tsv", rows)
    open("plots/for_paper/experiments_2_to_4_dataset.txt", "w") do io
        println(io, "successful_snapshots=$(length(data.case_ids))")
        println(io, "train_count=$TRAIN_COUNT")
        println(io, "holdout_count=$HOLDOUT_COUNT")
        println(io, "physical_grid=$(join(data.physical_grid, 'x'))")
        println(io, "saved_array_shape=$(join(data.shape, 'x'))")
        println(io, "parameter_dimension=$(size(data.Mu, 1))")
        println(io, "ambient_temperature_K=$AMBIENT_TEMPERATURE_K")
    end
end

function main()
    println("Loading fixed 50-snapshot dataset (no FVM will be run)...")
    data = load_fixed_dataset()
    println("Physical grid: $(data.physical_grid); saved array shape: $(data.shape)")
    write_split_and_dataset_metadata(data)

    println("Evaluating Experiment 2...")
    _, _, baseline_pod = evaluate_snapshot_count(data)
    println("Evaluating Experiment 3...")
    evaluate_pod_modes(data, baseline_pod)
    println("Evaluating Experiment 4...")
    evaluate_rbf_parameters(data, baseline_pod)
    println("Experiments 2--4 outputs regenerated successfully.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
