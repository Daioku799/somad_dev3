# 縮約モデルを用いた探索と本数の走査（Req 6.1〜6.4）
#
#   julia -t auto --project=H2-rom runs/paper_final_20260824T0140JST/optimize.jl
#
# 環境変数 N_RESTART で リスタート数を上書きできる（速度の実測用）。
# 環境変数 BUDGETS で走査する本数を絞れる（例: BUDGETS=36,48,60）。

using Printf, Dates, Statistics, Base.Threads

include(joinpath(@__DIR__, "common.jl"))

function main()
    started = now()
    @printf("=== optimize start %s（スレッド %d）===\n", started, nthreads())

    ds = load_main(CFG)
    prov = make_provenance(CFG, ds)
    geom = load_geometry(CFG, ds)
    inner = (ds.shape[1] - 2, ds.shape[2] - 2, ds.shape[3] - 2)
    cap, ncell = ds.cap, ds.ncell
    tr = split_indices(ds, "train")

    model_path = resolve_output(prov, "rom_model.jld2")
    isfile(model_path) || error("縮約モデルが無い。先に build_rom.jl を実行する: $model_path")
    model = load_rom(model_path)
    @printf("縮約モデル: %d 基底、設計 %d セル（上限 %d）\n", model.settings.modes, ncell, cap)

    # --- 探索用の高速な最大温度評価器 ------------------------------------
    t0 = time()
    rows = hot_row_indices(ds.field, tr, CFG.search_top_rows)
    ev = tmax_evaluator(model, rows)
    @printf("上位 %d 行を選定（%.1f 秒、全 %d 行の %.2f%%）\n",
            length(rows), time() - t0, size(ds.field, 1),
            length(rows) / size(ds.field, 1) * 100)

    # 限定が厳密であることを、学習に用いていないケースで確認する
    hold = vcat(split_indices(ds, "validation"), split_indices(ds, "test"))
    worst = maximum(abs(ev(@view ds.mu[:, i]) - predict_tmax(model, @view ds.mu[:, i]))
                    for i in hold)
    @printf("限定行と全行の一致: 最大差 %.3e K（%d 件）\n", worst, length(hold))
    if worst > 1e-6
        record_warning!(prov, "限定行での最大温度が全行と $(worst) K ずれる。行数を増やす必要がある")
        @printf("[警告] ずれが大きい。CFG.search_top_rows を増やすこと\n")
    end

    # --- 目的関数（設計ベクトル -> スカラー）------------------------------
    tmax_of(counts) = ev(Float64.(counts) ./ cap)
    third_of(counts) = field_metrics(predict_field(model, Float64.(counts) ./ cap),
                                     inner, geom).grad3d_max

    third = JSON.parsefile(resolve_output(prov, "third_objective.json"))
    @printf("第3目的: %s\n\n", third["label"])

    n_restart = parse(Int, get(ENV, "N_RESTART", string(CFG.n_restart)))
    targets = haskey(ENV, "BUDGETS") ?
              [parse(Int, x) for x in split(ENV["BUDGETS"], ",")] :
              in_range_budgets(CFG.sweep_budgets, CFG.train_budgets)
    targets = in_range_budgets(targets, CFG.train_budgets)
    @printf("走査する本数 %d 点（%s）、リスタート %d 回\n",
            length(targets), string(extrema(targets)), n_restart)

    # --- 本数の走査（水準ごとに独立なのでスレッドに分ける）----------------
    t0 = time()
    results = Vector{Any}(undef, length(targets))
    elapsed = zeros(length(targets))
    @threads for k in eachindex(targets)
        s = time()
        cfg = SearchConfig(cap = cap, ncell = ncell, n_restart = n_restart,
                           seed = CFG.seed_search + targets[k])
        results[k] = only(budget_sweep(tmax_of, [targets[k]], cfg))
        elapsed[k] = time() - s
    end
    @printf("走査 %.1f 分（1水準あたり %.1f 秒、合計評価 %d 回）\n\n",
            (time() - t0) / 60, mean(elapsed), sum(r.n_eval for r in results))

    # --- 出力 -------------------------------------------------------------
    println("=== 本数ごとの最良・最悪・一様 ===")
    @printf("%5s %11s %11s %11s %10s %10s %7s %7s\n",
            "N", "最良Tmax", "一様Tmax", "最悪Tmax", "最良-一様", "最悪-最良", "谷(最良)", "谷(最悪)")
    rows_out = Any[]
    for r in results
        @printf("%5d %11.4f %11.4f %11.4f %10.4f %10.4f %7d %7d\n",
                r.budget, r.best.value, r.uniform_value, r.worst.value,
                r.best.value - r.uniform_value, r.spread,
                r.n_distinct_best, r.n_distinct_worst)
        push!(rows_out, [r.budget, r.best.value, r.uniform_value, r.worst.value,
                         r.best.value - r.uniform_value, r.spread,
                         r.n_distinct_best, r.n_distinct_worst,
                         join(r.best.counts, ","), join(r.uniform_counts, ","),
                         join(r.worst.counts, ","), r.n_eval])
    end
    write_table(prov, "budget_sweep.tsv",
                ["budget", "tmax_best", "tmax_uniform", "tmax_worst",
                 "best_minus_uniform", "spread", "n_distinct_best", "n_distinct_worst",
                 "counts_best", "counts_uniform", "counts_worst", "n_eval"],
                rows_out; scope = "per_budget")

    # 走査で得た設計での第3目的（全再構成が要るので設計数を絞ってから評価する）
    println("\n=== 走査で得た設計での第3目的 ===")
    @printf("%5s %14s %14s %14s\n", "N", "最良での値", "一様での値", "最悪での値")
    third_rows = Any[]
    for r in results
        tb, tu, tw = third_of(r.best.counts), third_of(r.uniform_counts), third_of(r.worst.counts)
        @printf("%5d %14.5g %14.5g %14.5g\n", r.budget, tb, tu, tw)
        push!(third_rows, [r.budget, third["adopted"], tb, tu, tw,
                           r.best.value, r.uniform_value, r.worst.value])
    end
    write_table(prov, "budget_sweep_third.tsv",
                ["budget", "metric", "third_best_design", "third_uniform", "third_worst_design",
                 "tmax_best", "tmax_uniform", "tmax_worst"],
                third_rows; scope = "per_budget")

    set_model_settings!(prov; rbf_settings = merge(prov.rbf_settings, Dict{String,Any}(
        "search_n_restart" => n_restart, "search_top_rows" => length(rows),
        "search_seed_base" => CFG.seed_search)))
    record_seed!(prov, "search", CFG.seed_search)
    write_provenance(prov)
    write_warnings(prov)
    @printf("\n=== optimize end %s（所要 %.1f 分）===\n",
            now(), (now() - started).value / 60000)
end

main()
