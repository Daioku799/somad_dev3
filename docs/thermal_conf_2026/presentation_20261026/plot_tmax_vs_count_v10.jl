ENV["GKSwstype"] = "100"

# 発表v10用：TSV本数と最高温度（ROM予測値の2系列のみ）。
# v7（plot_experiment_results_v7.jl の tradeoff_plot）と同じ入力・処理で、
# FVM確認値（三角・星）の重ね描きを除き、スライドの高さに合わせて縦横比を変えた。

using Plots
using SHA

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const ROM = joinpath(ROOT, "runs", "paper_final_20260824T0140JST", "rom")
const OUT = joinpath(@__DIR__, "tmax_vs_count_v10.png")

const BLUE = RGB(0.12, 0.38, 0.68)
const GREY = RGB(0.48, 0.52, 0.56)

function read_tsv(path)
    lines = filter(line -> !isempty(line) && !startswith(line, "#"), readlines(path))
    header = split(lines[1], '\t')
    header, [split(line, '\t') for line in lines[2:end]]
end

function main()
    header, rows = read_tsv(joinpath(ROM, "budget_sweep.tsv"))
    idx = Dict(name => i for (i, name) in enumerate(header))
    budgets = parse.(Int, getindex.(rows, idx["budget"]))
    best = parse.(Float64, getindex.(rows, idx["tmax_best"]))
    uniform = parse.(Float64, getindex.(rows, idx["tmax_uniform"]))
    budgets == collect(36:60) || error("budget sweep is not N=36:60")

    p = plot(; xlabel = "TSV count N", ylabel = "Tmax [K]",
             xticks = 36:4:60, guidefontsize = 16, tickfontsize = 14,
             legendfontsize = 14, legend = :topright, gridalpha = 0.20,
             framestyle = :box, fontfamily = "DejaVu Sans",
             size = (1100, 380), dpi = 300, background_color = :white,
             left_margin = 9Plots.mm, bottom_margin = 10Plots.mm)
    plot!(p, budgets, uniform; color = GREY, linewidth = 3.0, marker = :circle,
          markersize = 3.8, label = "Uniform (ROM prediction)")
    plot!(p, budgets, best; color = BLUE, linewidth = 3.0, marker = :circle,
          markersize = 3.8, label = "Searched candidate (ROM prediction)")
    savefig(p, OUT)
    println("tmax_vs_count_v10.png sha256 = ", bytes2hex(open(sha256, OUT)))
end

main()
