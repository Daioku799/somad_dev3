ENV["GKSwstype"] = "100"

# スライド11用：探索候補（best_N48）と一様配置（uniform_N48）のFVM温度場（XY断面）。
# 既存のFVM再検証snapshotの theta をそのまま描く（新規計算なし）。
# 断面は両配置の全体最高温度がある高さ（最下層Si層の発熱層）。色尺度は2枚で共通。

using JLD2
using Plots
using Printf
using SHA

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const VERIFY = joinpath(ROOT, "runs", "paper_final_20260824T0140JST", "verify")
const SUMMARY = joinpath(ROOT, "docs", "thermal_conf_2026", "derived", "verification_summary.tsv")
const OUT_DIR = @__DIR__
const CASES = (("best_N48", "temperature_best_N48_v11.png"),
               ("uniform_N48", "temperature_uniform_N48_v11.png"))

file_sha256(path) = bytes2hex(open(sha256, path))

function reported_fvm(name)
    for line in readlines(SUMMARY)
        cols = split(line, '\t')
        cols[1] == name && return parse(Float64, cols[4])
    end
    error("not in verification_summary: $name")
end

function main()
    snaps = Dict(c => JLD2.load(joinpath(VERIFY, c, "snapshot.jld2")) for (c, _) in CASES)
    planes = Dict{String,Matrix{Float64}}()
    ks = Int[]
    for (c, _) in CASES
        inner = snaps[c]["theta"][2:end-1, 2:end-1, 2:end-1]
        tmax, idx = findmax(inner)
        abs(tmax - reported_fvm(c)) < 1e-6 || error("$c: Tmax $(tmax) differs from verification_summary")
        push!(ks, Tuple(idx)[3])
        planes[c] = inner[:, :, Tuple(idx)[3]]
        @printf("%s: Tmax %.6f K at inner index %s\n", c, tmax, string(Tuple(idx)))
    end
    allequal(ks) || error("Tmax heights differ: $(ks)")
    k = ks[1]
    z = snaps[CASES[1][1]]["z_centers"][k + 1]
    lo = minimum(minimum(v) for v in values(planes))
    hi = maximum(maximum(v) for v in values(planes))
    n = size(planes[CASES[1][1]], 1)
    edges = collect(range(0.0, 1.2; length = n + 1))
    for (c, out) in CASES
        v = planes[c]
        p = heatmap(edges, edges, permutedims(v); color = :inferno, clims = (lo, hi),
                    xlims = (0.0, 1.2), ylims = (0.0, 1.2), aspect_ratio = :equal,
                    xlabel = "Position X [mm]", ylabel = "Position Y [mm]",
                    colorbar_title = "T [K]",
                    title = @sprintf("FVM, z = %.4f mm, Tmax = %.3f K", z * 1e3, maximum(v)),
                    titlefontsize = 13, guidefontsize = 11, tickfontsize = 10,
                    colorbar_titlefontsize = 11, fontfamily = "DejaVu Sans", framestyle = :box,
                    size = (760, 640), dpi = 300, background_color = :white)
        # 発熱ブロックの輪郭（0.2 mm角、中心 0.4/0.8 mm）
        for x0 in (0.3, 0.7), y0 in (0.3, 0.7)
            plot!(p, [x0, x0 + 0.2, x0 + 0.2, x0, x0], [y0, y0, y0 + 0.2, y0 + 0.2, y0];
                  color = :white, linestyle = :dash, linewidth = 1.5, label = "")
        end
        path = joinpath(OUT_DIR, out)
        savefig(p, path)
        println(out, " sha256 = ", file_sha256(path))
    end
    @printf("color range %.3f .. %.3f K\n", lo, hi)
end

main()
