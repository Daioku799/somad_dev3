# 第3目的の候補の算出・統計量・予測精度・選定（Req 4.1〜4.7）
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

    # --- 候補指標の予測精度（Req 4.5）------------------------------------
    # 実測の温度場から算出した値と、縮約モデルが再構成した温度場から算出した値を比べる。
    # 勾配は微分が高波数を増幅するため、温度場の誤差より大きくなりうる。
    model_path = resolve_output(prov, "rom_model.jld2")
    if !isfile(model_path)
        record_warning!(prov, "縮約モデル $(model_path) が無いため候補の予測精度を評価できない")
        @printf("\n[警告] 縮約モデルが無いため予測精度を飛ばす: %s\n", model_path)
    else
        model = load_rom(model_path)
        hold = vcat(split_indices(ds, "validation"), split_indices(ds, "test"))
        @printf("\n=== 候補指標の予測精度（holdout %d 件）===\n", length(hold))

        t1 = time()
        recon = Dict(name => Vector{Float64}(undef, length(hold)) for name in FIELD_METRIC_NAMES)
        for (j, i) in enumerate(hold)
            p = predict_field(model, @view ds.mu[:, i])
            fmi = field_metrics(p, inner, geom)
            for name in FIELD_METRIC_NAMES
                recon[name][j] = getproperty(fmi, Symbol(name))
            end
        end
        @printf("再構成温度場からの再算出: %.1f 秒\n\n", time() - t1)

        # 幅は水準ごとに違うので、判定には holdout に含まれる水準の幅の中央を使う
        hold_budgets = sort(unique(ds.records[i].budget for i in hold))
        rows = Any[]
        @printf("%-30s %11s %11s %11s %9s %9s %s\n",
                "候補", "MAE", "RMSE", "max|e|", "誤差/幅", "順位相関", "判定")
        for sp in ALL_METRIC_SPECS
            if !has_prediction_error(sp)
                # 設計変数由来の候補は温度場を経ないため予測誤差を持たない
                push!(rows, [sp.name, string(sp.source), length(hold),
                             0.0, 0.0, 0.0, 0.0, 0.0, 1.0, true])
                @printf("%-30s %11s %11s %11s %9s %9s %s\n",
                        sp.label, "-", "-", "-", "0.000", "1.000", "合格（設計変数由来）")
                continue
            end
            truth = value_of[sp.name][hold]
            pred = recon[sp.name]
            # その候補が設計によって取りうる幅（水準ごとの幅の中央値）
            spread = median([metric_stats(value_of[sp.name][budget_indices(ds, b)],
                                          ds.tmax[budget_indices(ds, b)]).range
                             for b in hold_budgets])
            e = metric_prediction_error(truth, pred; spread = spread)
            ok = e.error_ratio < CFG.max_error_ratio
            push!(rows, [sp.name, string(sp.source), e.n, e.mae, e.rmse, e.maxe,
                         e.bias, e.error_ratio, e.spearman, ok])
            @printf("%-30s %11.4g %11.4g %11.4g %9.3f %9.3f %s\n",
                    sp.label, e.mae, e.rmse, e.maxe, e.error_ratio, e.spearman,
                    ok ? "合格" : @sprintf("不合格（上限 %.2f）", CFG.max_error_ratio))
            ok || record_warning!(prov,
                "候補 $(sp.name) の予測誤差が幅の $(round(e.error_ratio, digits=3)) 倍で、" *
                "上限 $(CFG.max_error_ratio) を超える")
        end
        write_table(prov, "objective_prediction_error.tsv",
                    ["metric", "source", "n", "mae", "rmse", "maxe", "bias",
                     "error_ratio", "spearman_truth_vs_pred", "passes_predictability"],
                    rows)

        write_table(prov, "objective_prediction_cases.tsv",
                    vcat(["name", "split", "budget"],
                         vcat([[k * "_fvm", k * "_rom"] for k in FIELD_METRIC_NAMES]...)),
                    [begin
                         r = ds.records[hold[j]]
                         vcat([r.name, r.split, r.budget],
                              vcat([[value_of[k][hold[j]], recon[k][j]]
                                    for k in FIELD_METRIC_NAMES]...))
                     end for j in eachindex(hold)])

        # --- 第3目的の選定（Req 4.3, 4.4, 4.6, 4.7）------------------------
        err_of = Dict(String(r[1]) => Float64(r[8]) for r in rows)
        cand = [(name = sp.name, source = sp.source,
                 max_abs_spearman = maximum(abs(spearman(ds.tmax[budget_indices(ds, b)],
                                                          value_of[sp.name][budget_indices(ds, b)]))
                                             for b in lv),
                 error_ratio = err_of[sp.name]) for sp in ALL_METRIC_SPECS]

        ovr = isempty(CFG.third_objective_override) ? nothing : CFG.third_objective_override
        adopted, verdicts = select_third_objective(cand;
                                max_abs_spearman = CFG.max_abs_spearman,
                                max_error_ratio = CFG.max_error_ratio,
                                fallback = first(DESIGN_METRIC_NAMES), override = ovr)

        println("\n=== 第3目的の判定 ===")
        @printf("独立性の上限 |ρ| < %.2f、予測可能性の上限 誤差/幅 < %.2f\n\n",
                CFG.max_abs_spearman, CFG.max_error_ratio)
        @printf("%-30s %8s %6s %8s %6s %4s %s\n",
                "候補", "max|ρ|", "独立", "誤差/幅", "予測可", "採用", "理由")
        for v in verdicts
            @printf("%-30s %8.3f %6s %8.3f %6s %4s %s\n",
                    metric_spec(v.name).label, v.max_abs_spearman,
                    v.independent ? "○" : "×", v.error_ratio,
                    v.predictable ? "○" : "×", v.adopted ? "★" : "", v.reason)
        end
        write_table(prov, "third_objective_verdicts.tsv",
                    ["metric", "source", "max_abs_spearman", "independent",
                     "error_ratio", "predictable", "adopted", "reason"],
                    [[v.name, string(v.source), v.max_abs_spearman, v.independent,
                      v.error_ratio, v.predictable, v.adopted, v.reason] for v in verdicts])

        # 後続の処理（探索・交換関係・図表）が参照する中間成果物
        sp = metric_spec(adopted)
        mech = only(v.name for v in verdicts if v.adopted)
        open(resolve_output(prov, "third_objective.json"), "w") do io
            JSON.print(io, Dict(
                "adopted" => adopted,
                "label" => sp.label,
                "source" => string(sp.source),
                "has_prediction_error" => has_prediction_error(sp),
                "fixed_by_decision" => ovr !== nothing,
                "max_abs_spearman_limit" => CFG.max_abs_spearman,
                "max_error_ratio_limit" => CFG.max_error_ratio,
                "verdicts" => [Dict("metric" => v.name, "independent" => v.independent,
                                    "predictable" => v.predictable, "adopted" => v.adopted,
                                    "max_abs_spearman" => v.max_abs_spearman,
                                    "error_ratio" => v.error_ratio, "reason" => v.reason)
                               for v in verdicts]), 1)
        end
        @printf("\n採用: %s（%s）\n", sp.label, ovr === nothing ? "機械的選定" : "決定により固定")
        ovr === nothing || record_warning!(prov,
            "第3目的は決定により $(adopted) に固定した。機械的選定の結果とは別に記録している")
    end

    write_provenance(prov)
    write_warnings(prov)
    @printf("\n=== objective_selection end %s（所要 %.1f 分）===\n",
            now(), (now() - started).value / 60000)
end

main()
