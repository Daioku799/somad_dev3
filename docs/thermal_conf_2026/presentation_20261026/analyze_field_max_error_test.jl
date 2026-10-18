ENV["GKSwstype"] = "100"

# 独立評価42配置における温度場全体の点ごとの最大誤差（補助スライド用）。
# 保存済みROMと既存のFVM温度場だけを用い、再学習・新規FVMは行わない。
# 作業票: work-order-field-max-error-20261019.json
#
#   julia --project=H2-rom docs/thermal_conf_2026/presentation_20261026/analyze_field_max_error_test.jl

using Printf, Statistics, LinearAlgebra
using Plots

include(joinpath(@__DIR__, "..", "..", "..", "runs", "paper_final_20260824T0140JST", "common.jl"))

const T_REF = 300.0
const OUT_TSV = joinpath(@__DIR__, "..", "derived", "field_max_error_test.tsv")
const OUT_PNG = joinpath(@__DIR__, "field_max_error_test.png")
# 既存の報告値（holdout_accuracy.tsv, split=test）
const REPORTED_MAE = 0.09496083028829935
const REPORTED_L2_RISE = 0.4933772932152032

function main()
    ds = load_main(CFG)
    model = load_rom(joinpath(CFG.run_dir, "rom", "rom_model.jld2"))
    names = [r.name for r in ds.records]
    te = split_indices(ds, "test")
    length(te) == 42 || error("expected 42 test cases, got $(length(te))")
    inner = (ds.shape[1] - 2, ds.shape[2] - 2, ds.shape[3] - 2)

    # 既存の評価関数で報告値を再現できることを先に確かめる
    rt = evaluate_accuracy(model, ds.field, ds.mu, te; names = names)
    @printf("再現: MAE %.10f (報告 %.10f) / L2上昇 %.10f%% (報告 %.10f%%)\n",
            rt.tmax_mae, REPORTED_MAE, rt.field_l2_rise, REPORTED_L2_RISE)
    abs(rt.tmax_mae - REPORTED_MAE) < 1e-9 && abs(rt.field_l2_rise - REPORTED_L2_RISE) < 1e-9 ||
        error("既存の報告値を再現できないため中止")

    rows = NamedTuple[]
    for i in te
        p = predict_field(model, @view ds.mu[:, i])
        t = @view ds.field[:, i]
        e = abs.(p .- t)
        k = argmax(e)
        ci = CartesianIndices(inner)[k]
        rise = maximum(t) - T_REF
        linf = e[k]
        p99 = quantile(e, 0.99)
        push!(rows, (name = names[i], budget = sum(round.(Int, ds.mu[:, i] .* 9)),
                     tmax_fvm = maximum(t), tmax_rom = maximum(p), rise_fvm = rise,
                     linf = linf, p99 = p99,
                     linf_pct = linf / rise * 100, p99_pct = p99 / rise * 100,
                     ix = ci[1], iy = ci[2], iz = ci[3]))
    end

    mkpath(dirname(OUT_TSV))
    open(OUT_TSV, "w") do io
        println(io, "# scope=split=test (42), field=inner cells $(inner), error=|T_ROM - T_FVM| [K], pct = value / (Tmax_FVM - 300 K) * 100")
        println(io, "name\tbudget\ttmax_fvm\ttmax_rom\trise_fvm\tmax_abs_err\tp99_abs_err\tmax_abs_err_pct_rise\tp99_abs_err_pct_rise\targmax_ix\targmax_iy\targmax_iz")
        for r in rows
            @printf(io, "%s\t%d\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.6f\t%.6f\t%d\t%d\t%d\n",
                    r.name, r.budget, r.tmax_fvm, r.tmax_rom, r.rise_fvm, r.linf, r.p99,
                    r.linf_pct, r.p99_pct, r.ix, r.iy, r.iz)
        end
    end

    stat(v) = @sprintf("mean %.4f  median %.4f  min %.4f  max %.4f", mean(v), median(v), minimum(v), maximum(v))
    println("\n=== 独立評価42配置 ===")
    println("最大誤差 [K]      : ", stat([r.linf for r in rows]))
    println("99%点誤差 [K]     : ", stat([r.p99 for r in rows]))
    println("最大誤差/上昇 [%] : ", stat([r.linf_pct for r in rows]))
    println("99%点/上昇 [%]    : ", stat([r.p99_pct for r in rows]))
    for n in (36, 48, 60)
        g = filter(r -> r.budget == n, rows)
        @printf("N=%d (%d件): 最大誤差 mean %.4f max %.4f K / 99%%点 mean %.4f K\n",
                n, length(g), mean(r.linf for r in g), maximum(r.linf for r in g), mean(r.p99 for r in g))
    end
    println("最大誤差の位置 iz の度数: ", sort(collect(Dict(z => count(r -> r.iz == z, rows) for z in unique(r.iz for r in rows)))))

    # 図: 本数別に各配置の最大誤差と99%点誤差を並べる（集計なし）
    order = sortperm([(r.budget, r.linf) for r in rows])
    xs = Float64[]
    for n in (36, 48, 60)
        idx = [k for k in order if rows[k].budget == n]
        append!(xs, n .+ range(-2.5, 2.5; length = length(idx)))
    end
    rs = rows[order]
    p = plot(; xlabel = "TSV count N", ylabel = "|T_ROM - T_FVM| [K]",
             xticks = [36, 48, 60], xlims = (31, 65), ylims = (0, ceil(maximum(r.linf for r in rows) * 5) / 5 + 0.1),
             guidefontsize = 16, tickfontsize = 14, legendfontsize = 13, legend = :topright,
             gridalpha = 0.20, framestyle = :box, fontfamily = "DejaVu Sans",
             size = (900, 520), dpi = 300, background_color = :white,
             left_margin = 4Plots.mm, bottom_margin = 4Plots.mm)
    scatter!(p, xs, [r.linf for r in rs]; marker = :diamond, markersize = 6,
             markercolor = RGB(0.88, 0.38, 0.14), markerstrokecolor = :white,
             label = "Max over field")
    scatter!(p, xs, [r.p99 for r in rs]; marker = :circle, markersize = 5,
             markercolor = RGB(0.12, 0.38, 0.68), markerstrokecolor = :white,
             label = "99th percentile")
    savefig(p, OUT_PNG)
    println("\n出力: ", OUT_TSV, "\n      ", OUT_PNG)
end

main()
