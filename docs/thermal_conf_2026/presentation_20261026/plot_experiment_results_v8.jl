ENV["GKSwstype"] = "100"

# 発表v8用の既存結果再描画（v7と同じ系列・処理。文字サイズ、線の記号、直接ラベルのみ変更）。
# 新しい数値実験は行わず、既存TSVの系列をそのまま可視化する。

using Plots
using Printf
using SHA

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const RUN = joinpath(ROOT, "runs", "paper_final_20260824T0140JST")
const ROM = joinpath(RUN, "rom")
const DERIVED = joinpath(ROOT, "docs", "thermal_conf_2026", "derived")
const OUT = @__DIR__

const PURPLE = RGB(0.455, 0.106, 0.278)
const BLUE = RGB(0.12, 0.38, 0.68)
const GREY = RGB(0.48, 0.52, 0.56)
const TEAL = RGB(0.05, 0.56, 0.55)
const ORANGE = RGB(0.88, 0.38, 0.14)

file_sha256(path) = bytes2hex(open(sha256, path))

function read_tsv(path)
    lines = filter(line -> !isempty(line) && !startswith(line, "#"), readlines(path))
    header = split(lines[1], '\t')
    rows = [split(line, '\t') for line in lines[2:end]]
    header, rows
end

column_index(header) = Dict(name => i for (i, name) in enumerate(header))

function accuracy_plot()
    header, rows = read_tsv(joinpath(ROM, "holdout_predictions.tsv"))
    idx = column_index(header)
    test = filter(row -> row[idx["split"]] == "test", rows)
    length(test) == 42 || error("expected 42 independent-evaluation rows, got $(length(test))")
    fvm = parse.(Float64, getindex.(test, idx["tmax_fvm"]))
    rom = parse.(Float64, getindex.(test, idx["tmax_rom"]))
    limits = (floor(minimum(vcat(fvm, rom)) * 10) / 10 - 0.1,
              ceil(maximum(vcat(fvm, rom)) * 10) / 10 + 0.1)
    p = plot(; xlabel="FVM Tmax [K]", ylabel="ROM Tmax [K]",
             xlims=limits, ylims=limits, aspect_ratio=:equal,
             guidefontsize=17, tickfontsize=14, legendfontsize=13,
             legend=:bottomright,
             gridalpha=0.20, framestyle=:box, fontfamily="DejaVu Sans",
             size=(690, 500), dpi=300, background_color=:white,
             left_margin=3Plots.mm, bottom_margin=3Plots.mm)
    plot!(p, collect(limits), collect(limits); color=:black, linestyle=:dash,
          linewidth=2.0, label="y = x")
    scatter!(p, fvm, rom; marker=:diamond, markersize=5.5,
             markercolor=ORANGE, markerstrokewidth=0.5,
             markerstrokecolor=:white, label="Independent (42)")
    annotate!(p, limits[1] + 0.18, limits[2] - 0.24,
              text("MAE = 0.0950 K", 16, :left, PURPLE))
    p
end

function verification_values()
    header, rows = read_tsv(joinpath(DERIVED, "verification_summary.tsv"))
    idx = column_index(header)
    values = Dict{String,NamedTuple}()
    for row in rows
        name = row[idx["name"]]
        name == "summary" && continue
        values[name] = (budget=parse(Int, row[idx["budget"]]),
                        rom=parse(Float64, row[idx["tmax_rom"]]),
                        fvm=parse(Float64, row[idx["tmax_fvm"]]))
    end
    values
end

function tradeoff_plot()
    header, rows = read_tsv(joinpath(ROM, "budget_sweep.tsv"))
    idx = column_index(header)
    budgets = parse.(Int, getindex.(rows, idx["budget"]))
    best = parse.(Float64, getindex.(rows, idx["tmax_best"]))
    uniform = parse.(Float64, getindex.(rows, idx["tmax_uniform"]))
    budgets == collect(36:60) || error("budget sweep is not N=36:60")

    p = plot(; xlabel="TSV count N", ylabel="Tmax [K]",
             xticks=36:4:60, xlims=(35, 64.5), guidefontsize=16, tickfontsize=14,
             legendfontsize=12, legend=:topright, gridalpha=0.20,
             framestyle=:box, fontfamily="DejaVu Sans",
             size=(1040, 470), dpi=300, background_color=:white,
             left_margin=4Plots.mm, bottom_margin=7Plots.mm)
    plot!(p, budgets, uniform; color=GREY, linewidth=3.0, marker=:rect,
          markersize=3.6, label="Uniform (ROM prediction)")
    plot!(p, budgets, best; color=BLUE, linewidth=3.0, marker=:circle,
          markersize=3.8, label="Searched candidate (ROM prediction)")
    # 色に頼らず読めるよう、線の右端に系列名を直接書く。
    annotate!(p, 60.5, uniform[end], text("Uniform", 14, :left, GREY))
    annotate!(p, 60.5, best[end], text("Searched", 14, :left, BLUE))

    verified = verification_values()
    vb = [36, 48, 60]
    best_fvm = [verified["best_N$n"].fvm for n in vb]
    uniform_fvm = [verified["uniform_N$n"].fvm for n in vb]
    scatter!(p, vb, uniform_fvm; marker=:utriangle, markersize=8,
             markercolor=:white, markerstrokecolor=GREY, markerstrokewidth=2.5,
             label="Uniform (FVM verification)")
    scatter!(p, vb, best_fvm; marker=:star5, markersize=10,
             markercolor=ORANGE, markerstrokecolor=:white, markerstrokewidth=0.8,
             label="Searched candidate (FVM verification)")
    p
end

function reduction_plot()
    verified = verification_values()
    budgets = [36, 48, 60]
    gain = [verified["uniform_N$n"].fvm - verified["best_N$n"].fvm for n in budgets]
    xpos = collect(1:3)
    p = bar(xpos, gain; bar_width=0.55, color=TEAL,
            linecolor=:black, linewidth=0.7, label="",
            xticks=(xpos, string.(budgets)), xlims=(0.4, 3.6), ylims=(0, 1.6),
            xlabel="TSV count N", ylabel="Tmax reduction vs. uniform [K]",
            guidefontsize=15, tickfontsize=14, gridalpha=0.18,
            framestyle=:box, fontfamily="DejaVu Sans",
            size=(500, 430), dpi=300, background_color=:white,
            left_margin=3Plots.mm, bottom_margin=3Plots.mm)
    for (i, value) in enumerate(gain)
        annotate!(p, i, value + 0.075,
                  text(@sprintf("%.3f K", value), 15, PURPLE))
    end
    p
end

function main()
    outputs = [
        ("rom_accuracy_independent_v8.png", accuracy_plot()),
        ("tmax_vs_count_v8.png", tradeoff_plot()),
        ("fvm_reduction_v8.png", reduction_plot()),
    ]
    for (name, p) in outputs
        path = joinpath(OUT, name)
        savefig(p, path)
        println(name, " sha256 = ", file_sha256(path))
    end
end

main()
