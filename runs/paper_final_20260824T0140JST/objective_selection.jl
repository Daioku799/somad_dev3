# 第3目的の候補となる指標の算出（Req 4.1）
#
#   julia --project=H2-rom runs/paper_final_20260824T0140JST/objective_selection.jl
#
# 温度場から算出する候補5種を全ケースについて求め、TSV本数の水準ごとに
# 値の範囲を出力する。採否の判定はここでは行わない。

using Printf, Dates, Statistics

include(joinpath(@__DIR__, "common.jl"))

const METRIC_LABEL = Dict(
    "hot_plane_dt"       => "最高温面の面内温度差 [K]",
    "hot_plane_grad_max" => "最高温面の面内最大勾配 [K/m]",
    "max_plane_dt"       => "全面での面内温度差の最大 [K]",
    "grad3d_max"         => "三次元勾配の最大 [K/m]",
    "grad3d_mean"        => "三次元勾配の平均 [K/m]")

function main()
    started = now()
    @printf("=== objective_selection start %s ===\n", started)

    ds = load_main(CFG)
    prov = make_provenance(CFG, ds)
    geom = load_geometry(CFG, ds)
    inner = (ds.shape[1] - 2, ds.shape[2] - 2, ds.shape[3] - 2)
    @printf("ケース %d 件、内部格子 %s\n", length(ds.records), string(inner))
    @printf("格子間隔: dx=%.3g m, dy=%.3g m, z は %d 点で非等間隔（%.3g 〜 %.3g m）\n\n",
            geom.dx, geom.dy, length(geom.z_centers),
            minimum(diff(geom.z_centers)), maximum(diff(geom.z_centers)))

    t0 = time()
    m = field_metrics_all(ds.field, inner, geom)
    @printf("候補5種を %d ケースについて算出（%.1f 秒）\n\n",
            length(ds.records), time() - t0)

    # --- ケースごとの値 ---------------------------------------------------
    write_table(prov, "objective_metrics.tsv",
                vcat(["name", "split", "budget", "sum_sq", "max_cell", "tmax",
                      "hot_plane_k"], collect(FIELD_METRIC_NAMES)),
                [begin
                     r = ds.records[i]
                     vcat([r.name, r.split, r.budget, r.sum_sq, r.max_cell,
                           ds.tmax[i], m.hot_plane_k[i]],
                          [getproperty(m, Symbol(k))[i] for k in FIELD_METRIC_NAMES])
                 end for i in eachindex(ds.records)])

    # --- 水準ごとの範囲 ---------------------------------------------------
    lv = budgets(ds)
    rows = Any[]
    for b in lv, k in FIELD_METRIC_NAMES
        idx = budget_indices(ds, b)
        v = getproperty(m, Symbol(k))[idx]
        push!(rows, [b, length(idx), k, minimum(v), maximum(v),
                     maximum(v) - minimum(v), mean(v), std(v)])
    end
    write_table(prov, "objective_metric_ranges.tsv",
                ["budget", "n", "metric", "min", "max", "range", "mean", "std"],
                rows; scope = "per_budget")

    println("=== 水準ごとの値の範囲 ===")
    for k in FIELD_METRIC_NAMES
        println("\n", METRIC_LABEL[k])
        @printf("  %-6s %5s %14s %14s %14s %12s\n", "N", "n", "min", "max", "range", "range/mean")
        for b in lv
            v = getproperty(m, Symbol(k))[budget_indices(ds, b)]
            lo, hi, mu = minimum(v), maximum(v), mean(v)
            @printf("  N=%-4d %5d %14.5g %14.5g %14.5g %11.2f%%\n",
                    b, length(v), lo, hi, hi - lo, mu == 0 ? 0.0 : (hi - lo) / abs(mu) * 100)
        end
    end

    # 最高温面がどこに乗っているかは、指標の意味を左右するため記録する
    hk = m.hot_plane_k
    println("\n最大温度が乗る面（内部添字）の分布:")
    for k in sort(unique(hk))
        @printf("  k=%-3d %4d 件（%.1f%%）\n", k, count(==(k), hk),
                count(==(k), hk) / length(hk) * 100)
    end

    write_provenance(prov)
    write_warnings(prov)
    @printf("\n=== objective_selection end %s（所要 %.1f 分）===\n",
            now(), (now() - started).value / 60000)
end

main()
