ENV["GKSwstype"] = "100"

# スライド11用：探索候補（best_N48）と一様配置（uniform_N48）の密度マップ。
# 描画仕様はスライド5（plot_density_example_v6.jl の density_panel）と同一。
# counts はFVM再検証のsnapshotの density_mu と一致することを確認してから描く。

using JLD2
using Plots
using Printf
using SHA

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const RUN = joinpath(ROOT, "runs", "paper_final_20260824T0140JST")
const CANDIDATES_PATH = joinpath(RUN, "rom", "verification_candidates.tsv")
const MAX_PER_CELL = 9
const OUT_DIR = @__DIR__

file_sha256(path) = bytes2hex(open(sha256, path))

function candidate_counts(name)
    lines = filter(l -> !startswith(l, "#") && !isempty(l), readlines(CANDIDATES_PATH))
    header = split(lines[1], '\t')
    i_name, i_counts = findfirst(==("name"), header), findfirst(==("counts"), header)
    for line in lines[2:end]
        cols = split(line, '\t')
        cols[i_name] == name && return parse.(Int, split(cols[i_counts], ','))
    end
    error("candidate not found: $(name)")
end

"""密度マップをセルごとのTSV本数で描く（色尺度0〜9本）。"""
function density_panel(counts)
    values = Float64.(reshape(counts, 4, 4)')
    edges = collect(range(0.1, 1.1; length=5))
    centers = (edges[1:end-1] .+ edges[2:end]) ./ 2
    p = heatmap(edges, edges, values; color=:YlGnBu, clims=(0, MAX_PER_CELL),
                xlims=(0.0, 1.2), ylims=(0.0, 1.2), aspect_ratio=:equal,
                xlabel="Position X [mm]", ylabel="Position Y [mm]",
                colorbar_title="TSVs per cell",
                title=@sprintf("Density map (N = %d)", sum(counts)),
                titlefontsize=13, guidefontsize=10, tickfontsize=9,
                colorbar_titlefontsize=10, colorbar_tickfontsize=9,
                fontfamily="DejaVu Sans", framestyle=:box,
                size=(760, 640), dpi=300, background_color=:white,
                left_margin=3Plots.mm, right_margin=4Plots.mm)
    for row in 1:4, col in 1:4
        v = Int(values[row, col])
        annotate!(p, centers[col], centers[row],
                  text(string(v), 14, v >= 5 ? :white : :black))
    end
    p
end


function main()
    for (case, out) in (("best_N48", "density_map_best_N48_v11.png"),
                        ("uniform_N48", "density_map_uniform_N48_v11.png"))
        snap = joinpath(RUN, "verify", case, "snapshot.jld2")
        counts = candidate_counts(case)
        mu = Float64.(JLD2.load(snap, "config_summary")["density_mu"])
        isapprox(mu .* MAX_PER_CELL, counts; atol=1e-9) ||
            error("$(case): density_mu does not match counts")
        path = joinpath(OUT_DIR, out)
        savefig(density_panel(counts), path)
        println(case, " counts = ", join(counts, ","), "  ", out, " sha256 = ", file_sha256(path))
    end
end

main()
