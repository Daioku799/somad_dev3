#!/usr/bin/env julia

using DelimitedFiles
using Plots
using Printf

function read_tsv(path::String)
    data, header = readdlm(path, '\t'; header=true)
    names = Symbol.(vec(header))
    [NamedTuple{Tuple(names)}(Tuple(data[row, :])) for row in axes(data, 1)]
end

function require_new_directory(path::String)
    ispath(path) && error("refusing to overwrite existing slide-figure directory: $path")
    mkpath(path)
end

function main(args=ARGS)
    length(args) == 1 || error("usage: julia generate_paper240_slide_plots.jl RUN_ROOT")
    run_root = abspath(args[1])
    output = joinpath(run_root, "slide_figures")
    require_new_directory(output)

    exp2 = read_tsv(joinpath(run_root, "02_snapshot_count", "experiment_2_summary.tsv"))
    x2 = Int.(getfield.(exp2, :nsnap))
    p2 = plot(x2, Float64.(getfield.(exp2, :mean_l2_percent));
        marker=:circle, linewidth=3, label="automatic k (RIC)", color=:steelblue,
        xlabel="Training snapshots", ylabel="Mean relative L2 error [%]",
        xticks=x2, size=(820, 520), title="Experiment 2: snapshot-count effect")
    plot!(p2, x2, Float64.(getfield.(exp2, :mean_fixed4_l2_percent));
        marker=:diamond, linewidth=2.5, label="fixed k=4", color=:black)
    savefig(p2, joinpath(output, "experiment_2_l2_only_240.png"))

    exp3 = read_tsv(joinpath(run_root, "03_pod_modes", "experiment_3_summary.tsv"))
    x3 = Int.(getfield.(exp3, :modes))
    p3 = plot(x3, Float64.(getfield.(exp3, :mean_l2_percent));
        marker=:circle, linewidth=3, label="POD + RBF", color=:steelblue,
        xlabel="Retained POD modes", ylabel="Mean relative L2 error [%]",
        xticks=x3, size=(820, 520), title="Experiment 3: retained-mode effect")
    plot!(p3, x3, Float64.(getfield.(exp3, :mean_projection_l2_percent));
        marker=:diamond, linewidth=2.5, label="POD projection lower bound", color=:black)
    savefig(p3, joinpath(output, "experiment_3_l2_only_240.png"))

    exp4 = read_tsv(joinpath(run_root, "04_rbf_parameters", "experiment_4_summary.tsv"))
    epsilons = sort(unique(Float64.(getfield.(exp4, :epsilon))))
    lambdas = sort(unique(Float64.(getfield.(exp4, :lambda))))
    values = [
        only(row for row in exp4 if Float64(row.epsilon) == epsilon && Float64(row.lambda) == lambda).mean_l2_percent
        for lambda in lambdas, epsilon in epsilons
    ]
    p4 = heatmap(1:length(epsilons), 1:length(lambdas), Float64.(values);
        xticks=(1:length(epsilons), string.(epsilons)),
        yticks=(1:length(lambdas), [@sprintf("%.0e", value) for value in lambdas]),
        xlabel="Gaussian RBF epsilon", ylabel="Regularization lambda",
        title="Experiment 4: mean relative L2 error [%]", color=:viridis,
        size=(820, 520))
    threshold = (minimum(values) + maximum(values)) / 2
    for row in axes(values, 1), column in axes(values, 2)
        color = values[row, column] > threshold ? :white : :black
        annotate!(p4, column, row, text(@sprintf("%.4f", values[row, column]), 10, color))
    end
    best = argmin(values)
    scatter!(p4, [best[2]], [best[1]]; marker=:rect, markersize=19,
        markercolor=:transparent, markerstrokecolor=:red, markerstrokewidth=3, label=false)
    savefig(p4, joinpath(output, "experiment_4_l2_heatmap_240.png"))

    println("Created three slide-specific figures in $output")
end

main()
