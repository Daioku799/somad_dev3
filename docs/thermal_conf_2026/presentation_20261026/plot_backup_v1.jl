ENV["GKSwstype"] = "100"

# 補助スライド v1 用の図。既存の保存データを描くだけで、新しい計算は行わない。
#   B1: セル内の候補位置と選ばれる順（模式図）＋ 実際の材料分布の拡大（random_N48）
#   B4: POD の累積寄与率（rom/pod_spectrum.tsv）
#   B6: モード数・ε・λ の選定（rom/rbf_grid.tsv、検証用42配置の最高温度MAE）
#
#   julia --project=H2-rom docs/thermal_conf_2026/presentation_20261026/plot_backup_v1.jl

using JLD2
using Plots
using Printf

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const RUN = joinpath(ROOT, "runs", "paper_final_20260824T0140JST")
const OUT_DIR = @__DIR__

const MAROON = RGB(0x74 / 255, 0x1b / 255, 0x47 / 255)
const ACCENT = RGB(0xa1 / 255, 0x3d / 255, 0x22 / 255)
const GRAY = RGB(0.55, 0.57, 0.60)

# 配置生成の幾何（H2-main-ext/src/ComponentGenerator/Layout.jl と同じ値）
const MARGIN_UM = 100.0
const CELL_UM = 250.0
const PITCH_UM = 80.0
const R_TSV_UM = 20.0
const SITE_UM = [45.0, 125.0, 205.0]   # セル内の候補位置（g + 余白 = 40 + 5 µm から 80 µm ピッチ）

function read_table(path)
    lines = filter(l -> !startswith(l, "#") && !isempty(l), readlines(path))
    header = split(lines[1], '\t')
    rows = [split(l, '\t') for l in lines[2:end]]
    return header, rows
end

circle(x, y, r; n = 60) = Shape([x + r * cos(t) for t in range(0, 2π; length = n)],
                                [y + r * sin(t) for t in range(0, 2π; length = n)])

# ---- B1(a) 模式図：候補 3×3 と順位 ----------------------------------------
function cell_rule_panel()
    p = plot(; xlims = (-28, CELL_UM + 28), ylims = (-40, CELL_UM + 56), aspect_ratio = :equal,
             axis = false, grid = false, legend = false, size = (620, 640), dpi = 300,
             background_color = :white, fontfamily = "DejaVu Sans")
    plot!(p, Shape([0, CELL_UM, CELL_UM, 0], [0, 0, CELL_UM, CELL_UM]);
          fillcolor = RGB(0.96, 0.96, 0.97), linecolor = MAROON, linewidth = 3)
    rankcol = Dict(1 => ACCENT, 2 => RGB(0.93, 0.62, 0.35), 3 => RGB(0.98, 0.85, 0.62))
    for (v, y) in enumerate(SITE_UM), (u, x) in enumerate(SITE_UM)
        rank = (u == 2 && v == 2) ? 1 : (u == 2 || v == 2) ? 2 : 3
        plot!(p, circle(x, y, R_TSV_UM); fillcolor = rankcol[rank], linecolor = :black, linewidth = 1.2)
        annotate!(p, x, y, text(string(rank), 20, rank == 1 ? :white : :black, :center, "DejaVu Sans"))
    end
    # 寸法線（ピッチとセル幅）
    plot!(p, [SITE_UM[2], SITE_UM[3]], [CELL_UM + 22, CELL_UM + 22]; color = :black, linewidth = 1.5,
          arrow = arrow(:both, :closed, 0.4, 0.4))
    annotate!(p, (SITE_UM[2] + SITE_UM[3]) / 2, CELL_UM + 42, text("80 µm", 15, :black, :center))
    plot!(p, [0, CELL_UM], [-20, -20]; color = :black, linewidth = 1.5, arrow = arrow(:both, :closed, 0.4, 0.4))
    annotate!(p, CELL_UM / 2, -33, text("250 µm", 15, :black, :center))
    return p
end

# ---- B1(b) 実際の材料分布をセル単位で拡大 ----------------------------------
function cell_zoom_panels(snapshot, cells)
    id = snapshot["id_map"]
    zc = snapshot["z_centers"]
    # TSV が全断面に現れる高さ（熱源層と重ならない z）を使う
    k = argmin(abs.(zc .- 0.3425e-3))
    sl = id[2:end-1, 2:end-1, k]
    h_um = 1200.0 / snapshot["nx"]
    panels = Any[]
    for (i, j, n) in cells
        x0 = MARGIN_UM + (i - 1) * CELL_UM
        y0 = MARGIN_UM + (j - 1) * CELL_UM
        ix = round(Int, x0 / h_um) .+ (1:round(Int, CELL_UM / h_um))
        iy = round(Int, y0 / h_um) .+ (1:round(Int, CELL_UM / h_um))
        tsv = Float64.(sl[ix, iy] .== 1)'
        edges = collect(range(0, CELL_UM; length = length(ix) + 1))
        p = heatmap(edges, edges, tsv; color = cgrad([RGB(0.80, 0.80, 0.82), RGB(0.98, 0.84, 0.10)]),
                    clims = (0, 1), colorbar = false, aspect_ratio = :equal,
                    xlims = (0, CELL_UM), ylims = (0, CELL_UM), axis = false, grid = false,
                    framestyle = :box, title = "n = $n", titlefontsize = 22,
                    fontfamily = "DejaVu Sans", legend = false)
        for y in SITE_UM, x in SITE_UM
            plot!(p, circle(x, y, R_TSV_UM + 4); fillalpha = 0, linecolor = GRAY, linestyle = :dash, linewidth = 1)
        end
        push!(panels, p)
    end
    return plot(panels...; layout = (1, length(panels)), size = (330 * length(panels), 360), dpi = 300,
                background_color = :white, left_margin = 2Plots.mm, right_margin = 2Plots.mm)
end

# ---- B4 累積寄与率 ---------------------------------------------------------
function ric_panel()
    _, rows = read_table(joinpath(RUN, "rom", "pod_spectrum.tsv"))
    m = [parse(Float64, r[1]) for r in rows]
    ric = [parse(Float64, r[3]) for r in rows]
    resid = 1 .- ric
    p = plot(m[1:end-1], resid[1:end-1]; yscale = :log10, marker = :circle, markersize = 4,
             color = MAROON, linewidth = 2, legend = false,
             xlabel = "Number of POD modes r", ylabel = "1 − cumulative contribution",
             xlims = (0, 61), ylims = (1e-6, 0.1), yticks = 10.0 .^ (-6:-1),
             guidefontsize = 18, tickfontsize = 15, gridalpha = 0.2, framestyle = :box,
             fontfamily = "DejaVu Sans", size = (900, 560), dpi = 300, background_color = :white,
             left_margin = 5Plots.mm, bottom_margin = 5Plots.mm)
    k = 24
    scatter!(p, [m[k]], [resid[k]]; marker = :star5, markersize = 14, color = ACCENT, markerstrokecolor = :black)
    annotate!(p, m[k] + 2, resid[k] * 2.6, text(@sprintf("r = 24:  %.6f", ric[k]), 16, ACCENT, :left))
    for (kk, lab) in ((1, "r = 1"), (4, "r = 4"))
        annotate!(p, m[kk] + 1.2, resid[kk] * 1.6, text(@sprintf("%s:  %.4f", lab, ric[kk]), 14, :black, :left))
    end
    return p, ric
end

# ---- B6 モード数・ε・λ の選定 ---------------------------------------------
function selection_panel()
    header, rows = read_table(joinpath(RUN, "rom", "rbf_grid.tsv"))
    col(name) = findfirst(==(name), header)
    data = [(m = parse(Float64, r[col("modes")]), e = parse(Float64, r[col("epsilon")]),
             l = parse(Float64, r[col("lambda")]), mae = parse(Float64, r[col("tmax_mae")])) for r in rows]
    eps_list = sort(unique(d.e for d in data))
    modes = sort(unique(d.m for d in data))
    shades = [MAROON, ACCENT, RGB(0.85, 0.50, 0.25), RGB(0.40, 0.55, 0.75), RGB(0.55, 0.60, 0.65), RGB(0.75, 0.77, 0.80)]
    shapes = [:circle, :diamond, :utriangle, :square, :dtriangle, :hexagon]
    p = plot(; xscale = :log10, yscale = :log10, xticks = (modes, string.(Int.(modes))),
             yticks = ([0.05, 0.1, 0.2, 0.5, 1.0], ["0.05", "0.1", "0.2", "0.5", "1"]),
             ylims = (0.05, 1.6), xlims = (2.6, 56),
             xlabel = "Number of POD modes r", ylabel = "Tmax MAE on 42 selection layouts [K]",
             guidefontsize = 17, tickfontsize = 15, legendfontsize = 14, legend = :outerright,
             gridalpha = 0.2, framestyle = :box, fontfamily = "DejaVu Sans",
             size = (1100, 560), dpi = 300, background_color = :white,
             left_margin = 5Plots.mm, bottom_margin = 5Plots.mm)
    for (q, e) in enumerate(eps_list)
        best = [minimum(d.mae for d in data if d.m == m && d.e == e) for m in modes]
        plot!(p, modes, best; color = shades[q], marker = shapes[q], markersize = 6, linewidth = 2,
              markerstrokecolor = :white, label = "ε = $(e)")
    end
    b = argmin([d.mae for d in data])
    scatter!(p, [data[b].m], [data[b].mae]; marker = :star5, markersize = 15, color = ACCENT,
             markerstrokecolor = :black, label = "adopted")
    return p, data[b], length(data)
end

function main()
    savefig(cell_rule_panel(), joinpath(OUT_DIR, "backup_cell_rule_v1.png"))

    snapshot = JLD2.load(joinpath(RUN, "verify", "random_N48", "snapshot.jld2"))
    # random_N48 の本数（verification_candidates.tsv）: セル (i, j) は x が i、y が j
    cells = [(2, 1, 1), (1, 1, 2), (4, 1, 5), (1, 2, 6)]
    savefig(cell_zoom_panels(snapshot, cells), joinpath(OUT_DIR, "backup_cell_examples_v1.png"))

    p, ric = ric_panel()
    savefig(p, joinpath(OUT_DIR, "backup_pod_ric_v1.png"))
    @printf("累積寄与率: r=1 %.6f, r=4 %.6f, r=24 %.6f（保持した%d基底に対する比）\n", ric[1], ric[4], ric[24], length(ric))

    p, best, n = selection_panel()
    savefig(p, joinpath(OUT_DIR, "backup_rbf_selection_v1.png"))
    @printf("選定: %d 通り中 最良 r=%d ε=%.2f λ=%.0e MAE=%.6f K\n", n, best.m, best.e, best.l, best.mae)
end

main()
