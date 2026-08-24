#!/usr/bin/env julia
# 各層（特にシリコン層）の温度場と ID マップを描く確認用スクリプト
#
#   julia --project=H2-rom tools/plot_layers.jl <snapshot.jld2> [出力先]
#
# 層と格子の対応は、同じケースディレクトリの config.json の層構成
# （分割数の累積）から決める。スナップショット側の z_faces には依存しない。

ENV["GKSwstype"] = "nul"

using JLD2, JSON, Plots, Printf, Statistics
using Plots.PlotMeasures

const MATERIALS = [(1, "Copper (TSV)", :yellow), (2, "Silicon", :gray),
                   (3, "Solder (bump)", :purple), (4, "PCB", :orange),
                   (5, "Heatsink", :blue), (6, "Resin", :green),
                   (7, "PowerSource", :red)]
const MATERIAL_COLORS = [m[3] for m in MATERIALS]

"""層名・内部 k 添字の範囲・z 範囲[m] を、config.json の層構成から求める。"""
function layer_ranges(config_path::AbstractString)
    cfg = JSON.parsefile(config_path)
    out = Tuple{String,UnitRange{Int},Float64,Float64}[]
    k, z = 1, 0.0
    for L in cfg["layers"]
        d, t = Int(L["divisions"]), Float64(L["thickness"])
        push!(out, (String(L["name"]), k:(k + d - 1), z, z + t))
        k += d
        z += t
    end
    return out
end

"""内部 k 添字を配列添字に直す（ゴースト1層ぶんずらす）。"""
arr_k(k_internal::Int) = k_internal + 1

interior(a, k) = a[2:end-1, 2:end-1, k]

function load_case(path::AbstractString)
    d = load(path)
    θ = haskey(d, "theta") ? d["theta"] : d["temperature"]
    return (theta = θ, id_map = d["id_map"], z_centers = d["z_centers"],
            nx = d["nx"], ny = d["ny"], nz = d["nz"])
end

function axes_mm(nx, ny; lx = 1.2e-3, ly = 1.2e-3)
    dx, dy = lx / nx, ly / ny
    return [(i - 0.5) * dx * 1e3 for i in 1:nx], [(j - 0.5) * dy * 1e3 for j in 1:ny]
end

function temp_panel(x, y, s, title; clims, cbar = true, ylab = true)
    heatmap(x, y, s'; c = :thermal, clims = clims, aspect_ratio = :equal,
            xlims = (0, 1.2), ylims = (0, 1.2), title = title, titlefontsize = 9,
            xlabel = "X [mm]", ylabel = ylab ? "Y [mm]" : "",
            colorbar = cbar, colorbar_title = cbar ? "T [K]" : "",
            tickfontsize = 7, guidefontsize = 8,
            left_margin = 5mm, right_margin = 5mm, bottom_margin = 6mm, top_margin = 5mm)
end

function id_panel(x, y, s, title; ylab = true)
    heatmap(x, y, Float64.(s)'; c = cgrad(MATERIAL_COLORS, 7, categorical = true),
            clims = (0.5, 7.5), aspect_ratio = :equal, xlims = (0, 1.2), ylims = (0, 1.2),
            title = title, titlefontsize = 9, xlabel = "X [mm]",
            ylabel = ylab ? "Y [mm]" : "", colorbar = false, interpolate = false,
            tickfontsize = 7, guidefontsize = 8,
            left_margin = 5mm, right_margin = 5mm, bottom_margin = 6mm, top_margin = 5mm)
end

"""材料 ID と色の対応を示す凡例パネル。"""
function legend_panel()
    p = plot(framestyle = :none, legend = :left, legendfontsize = 9,
             xlims = (0, 1), ylims = (0, 1), title = "Material ID", titlefontsize = 9)
    for (id, name, col) in MATERIALS
        scatter!(p, [-1], [-1], color = col, markershape = :square, markersize = 7,
                 markerstrokewidth = 0, label = " $id  $name")
    end
    return p
end

"""その層のうち PowerSource を最も多く含む断面（発熱面）の配列添字。"""
function power_plane(id_map, rng)
    best_k, best_n = arr_k(first(rng)), -1
    for ki in rng
        n = count(==(7), interior(id_map, arr_k(ki)))
        n > best_n && ((best_k, best_n) = (arr_k(ki), n))
    end
    return best_k
end

function main(snapshot_path, out_dir)
    case_dir = dirname(snapshot_path)
    config_path = joinpath(case_dir, "config.json")
    isfile(config_path) || error("config.json が見つからない: $config_path")

    c = load_case(snapshot_path)
    layers = layer_ranges(config_path)
    x, y = axes_mm(c.nx, c.ny)
    mkpath(out_dir)
    tag = basename(case_dir)

    # --- 層ごとの数値要約 -----------------------------------------------
    println("\n=== 層ごとの温度 ($(tag)) ===")
    @printf("%-12s %-9s %12s %10s %10s %9s\n", "層", "k(内部)", "z[um]", "Tmax[K]", "Tmean[K]", "面内幅[K]")
    for (name, rng, z0, z1) in layers
        blk = c.theta[2:end-1, 2:end-1, arr_k.(collect(rng))]
        @printf("%-12s %-9s %12s %10.4f %10.4f %9.4f\n", name, "$(first(rng))-$(last(rng))",
                @sprintf("%.0f-%.0f", z0 * 1e6, z1 * 1e6),
                maximum(blk), mean(blk), maximum(blk) - minimum(blk))
    end

    silicon = [l for l in layers if startswith(l[1], "Silicon")]
    isempty(silicon) && error("シリコン層が見つからない")
    nsi = length(silicon)

    si_ks = vcat([arr_k.(collect(rng)) for (_, rng, _, _) in silicon]...)
    si_block = c.theta[2:end-1, 2:end-1, si_ks]
    shared = (minimum(si_block), maximum(si_block))
    @printf("\nシリコン層の共通色範囲: %.4f - %.4f K（幅 %.4f K）\n",
            shared[1], shared[2], shared[2] - shared[1])

    pk = Dict(name => power_plane(c.id_map, rng) for (name, rng, _, _) in silicon)

    # --- 図1: ID マップ + 温度場（共通色範囲。層間の比較用）--------------
    panels = Plots.Plot[]
    for (i, (name, _, _, _)) in enumerate(silicon)
        k = pk[name]
        push!(panels, id_panel(x, y, interior(c.id_map, k),
              @sprintf("%s  ID  z=%.1fum", name, c.z_centers[k] * 1e6); ylab = i == 1))
    end
    push!(panels, legend_panel())
    for (i, (name, _, _, _)) in enumerate(silicon)
        k = pk[name]
        s = interior(c.theta, k)
        push!(panels, temp_panel(x, y, s, @sprintf("%s  T  max=%.3f K", name, maximum(s));
                                 clims = shared, cbar = true, ylab = i == 1))
    end
    push!(panels, plot(framestyle = :none))
    p = plot(panels..., layout = (2, nsi + 1), size = (480 * (nsi + 1), 900),
             plot_title = "$tag : silicon layers @ power-grid plane (shared color scale)",
             plot_titlefontsize = 12)
    savefig(p, joinpath(out_dir, "$(tag)_silicon_layers.png"))

    # --- 図2: 温度場（層ごとに色範囲を自動調整。面内構造を見る用）--------
    panels = Plots.Plot[]
    for (i, (name, rng, _, _)) in enumerate(silicon)
        k = pk[name]
        s = interior(c.theta, k)
        lo, hi = minimum(s), maximum(s)
        push!(panels, temp_panel(x, y, s,
              @sprintf("%s  z=%.1fum\nmax=%.3f  range=%.3f K", name, c.z_centers[k] * 1e6,
                       hi, hi - lo); clims = (lo, hi), ylab = i == 1))
    end
    p = plot(panels..., layout = (1, nsi), size = (520 * nsi, 480),
             plot_title = "$tag : silicon layers @ power-grid plane (per-layer color scale)",
             plot_titlefontsize = 12)
    savefig(p, joinpath(out_dir, "$(tag)_silicon_layers_autoscale.png"))

    # --- 図3: 各シリコン層の全断面 -------------------------------------
    ncol = maximum(length(rng) for (_, rng, _, _) in silicon)
    panels = Plots.Plot[]
    for (name, rng, _, _) in silicon
        blk = c.theta[2:end-1, 2:end-1, arr_k.(collect(rng))]
        row_clims = (minimum(blk), maximum(blk))     # 層内で色範囲を共有する
        for (i, ki) in enumerate(rng)
            k = arr_k(ki)
            s = interior(c.theta, k)
            mark = count(==(7), interior(c.id_map, k)) > 0 ? " [power]" : ""
            push!(panels, temp_panel(x, y, s,
                  @sprintf("%s #%d  z=%.1fum%s\nmax=%.3f", name, i, c.z_centers[k] * 1e6,
                           mark, maximum(s));
                  clims = row_clims, cbar = true, ylab = i == 1))
        end
        for _ in (length(rng) + 1):ncol
            push!(panels, plot(framestyle = :none))
        end
    end
    p = plot(panels..., layout = (nsi, ncol), size = (450 * ncol, 400 * nsi),
             plot_title = "$tag : every silicon sub-slice (color scale shared within each layer)",
             plot_titlefontsize = 12)
    savefig(p, joinpath(out_dir, "$(tag)_silicon_slices.png"))

    # --- 図4: 積層方向の断面（XZ）--------------------------------------
    jmid = div(c.ny, 2) + 1
    xz = c.theta[2:end-1, jmid, 2:end-1]
    zc_int = [c.z_centers[arr_k(k)] * 1e6 for k in 1:c.nz]
    p = heatmap(x, zc_int, xz'; c = :thermal, xlabel = "X [mm]", ylabel = "Z [um]",
                title = "$tag : XZ slice at y = 0.6 mm", colorbar_title = "T [K]",
                size = (900, 620), left_margin = 5mm, bottom_margin = 4mm)
    for (name, _, z0, z1) in layers
        hline!(p, [z1 * 1e6], color = :white, lw = 0.6, label = "")
        annotate!(p, 1.23, (z0 + z1) * 0.5 * 1e6, text(name, 7, :left, :black))
    end
    plot!(p, xlims = (0, 1.45), legend = false)
    savefig(p, joinpath(out_dir, "$(tag)_stack_xz.png"))

    println("\n出力: $out_dir")
    for f in sort(readdir(out_dir))
        endswith(f, ".png") && println("  ", f)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) >= 1 || error("使い方: julia --project=H2-rom tools/plot_layers.jl <snapshot.jld2> [出力先]")
    main(ARGS[1], length(ARGS) >= 2 ? ARGS[2] : "plots/layers")
end
