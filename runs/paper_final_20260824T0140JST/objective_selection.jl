# 第3目的の候補となる指標の算出と統計量（Req 4.1, 4.2）
#
#   julia --project=H2-rom runs/paper_final_20260824T0140JST/objective_selection.jl
#
# 温度場由来5種と設計変数由来1種を全ケースについて求め、TSV本数の水準ごとに
# 最大温度との順位相関と、設計によって取りうる幅を出力する。採否の判定は行わない。

using Printf, Dates, Statistics

include(joinpath(@__DIR__, "common.jl"))


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
    fm = field_metrics_all(ds.field, inner, geom)
    dm = design_metrics_all([r.counts for r in ds.records])
    @printf("候補 %d 種を %d ケースについて算出（%.1f 秒）\n",
            length(ALL_METRIC_SPECS), length(ds.records), time() - t0)

    # 設計変数由来の候補は、計画情報が持つ偏り指標と一致していなければならない
    mismatch = [ds.records[i].name for i in eachindex(ds.records)
                if dm.sum_sq[i] != ds.records[i].sum_sq]
    isempty(mismatch) ||
        error("偏り指標が計画情報と一致しない: $(join(first(mismatch, 5), ", "))")
    @printf("偏り指標は計画情報の値と全 %d 件で一致\n\n", length(ds.records))

    # 候補名 -> 全ケース分の値
    value_of = Dict{String,Vector{Float64}}()
    for name in FIELD_METRIC_NAMES
        value_of[name] = getproperty(fm, Symbol(name))
    end
    for name in DESIGN_METRIC_NAMES
        value_of[name] = Float64.(getproperty(dm, Symbol(name)))
    end

    # --- ケースごとの値 ---------------------------------------------------
    metric_names = [sp.name for sp in ALL_METRIC_SPECS]
    write_table(prov, "objective_metrics.tsv",
                vcat(["name", "split", "budget", "max_cell", "tmax", "hot_plane_k"],
                     metric_names),
                [begin
                     r = ds.records[i]
                     vcat([r.name, r.split, r.budget, r.max_cell,
                           ds.tmax[i], fm.hot_plane_k[i]],
                          [value_of[k][i] for k in metric_names])
                 end for i in eachindex(ds.records)])

    # --- 水準ごとの順位相関と幅（Req 4.2）---------------------------------
    lv = budgets(ds)
    rows = Any[]
    for sp in ALL_METRIC_SPECS, b in lv
        idx = budget_indices(ds, b)
        s = metric_stats(value_of[sp.name][idx], ds.tmax[idx])
        push!(rows, [b, s.n, sp.name, string(sp.source), has_prediction_error(sp),
                     s.spearman, s.min, s.max, s.range, s.mean, s.std, s.range_ratio])
    end
    write_table(prov, "objective_metric_stats.tsv",
                ["budget", "n", "metric", "source", "has_prediction_error",
                 "spearman_vs_tmax", "min", "max", "range", "mean", "std", "range_ratio"],
                rows; scope = "per_budget")

    println("=== 最大温度との順位相関（|値| が小さいほど独立）===")
    @printf("%-34s%s\n", "候補", join([lpad("N=$b", 9) for b in lv]))
    for sp in ALL_METRIC_SPECS
        line = rpad(sp.label, 34)
        for b in lv
            idx = budget_indices(ds, b)
            line *= @sprintf("%9.3f", spearman(ds.tmax[idx], value_of[sp.name][idx]))
        end
        flag = maximum(abs(spearman(ds.tmax[budget_indices(ds, b)],
                                    value_of[sp.name][budget_indices(ds, b)])) for b in lv)
        line *= flag < CFG.max_abs_spearman ? "   独立" : @sprintf("   上限%.2f超過", CFG.max_abs_spearman)
        println(line)
    end

    println("\n=== 設計によって取りうる幅 ===")
    for sp in ALL_METRIC_SPECS
        println("\n", sp.label)
        @printf("  %-7s %5s %14s %14s %14s %12s\n", "N", "n", "min", "max", "range", "range/mean")
        for b in lv
            s = metric_stats(value_of[sp.name][budget_indices(ds, b)],
                             ds.tmax[budget_indices(ds, b)])
            @printf("  N=%-5d %5d %14.5g %14.5g %14.5g %11.2f%%\n",
                    b, s.n, s.min, s.max, s.range, s.range_ratio * 100)
        end
    end

    # 最高温面がどこに乗っているかは、指標の意味を左右するため記録する
    hk = fm.hot_plane_k
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
