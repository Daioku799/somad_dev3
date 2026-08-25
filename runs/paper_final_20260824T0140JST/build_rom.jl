# 縮約モデルの構築と精度評価（Req 1.1, 1.2, 1.3, 2.1, 2.2, 2.5, 2.6）
#
#   julia --project=H2-rom runs/paper_final_20260824T0140JST/build_rom.jl
#
# 学習分割のみで基底と補間を構築し、学習に用いていない分割に対する
# 最大温度の3指標と温度場の相対 L2 誤差を出力する。条件は common.jl の CFG のみから受け取る。

using Printf, Dates, Statistics

include(joinpath(@__DIR__, "common.jl"))

# 補間の設定は探索する。基底数は RIC しきい値では決まらず、これが最も効く。
const MODES    = [3, 5, 8, 12, 16, 24, 32, 48, 64]
const EPSILONS = [0.05, 0.1, 0.25, 0.5, 1.0, 2.0]
const LAMBDAS  = [1e-8, 1e-6, 1e-4, 1e-2]

fmt(r) = @sprintf("%8.5f %8.5f %8.5f %9.5f %9.5f",
                  r.tmax_mae, r.tmax_rmse, r.tmax_maxe, r.field_l2_rel, r.field_l2_rise)

function main()
    started = now()
    @printf("=== build_rom start %s ===\n", started)

    ds = load_main(CFG)
    prov = make_provenance(CFG, ds)
    names = [r.name for r in ds.records]
    inner = (ds.shape[1] - 2, ds.shape[2] - 2, ds.shape[3] - 2)
    tr = split_indices(ds, "train")
    va = split_indices(ds, "validation")
    te = split_indices(ds, "test")
    @printf("ケース %d 件（train %d / validation %d / test %d）、内部格子 %s\n",
            length(ds.records), length(tr), length(va), length(te), string(inner))
    @printf("Tmax %.4f .. %.4f K（全体の幅 %.4f K）\n\n",
            minimum(ds.tmax), maximum(ds.tmax), maximum(ds.tmax) - minimum(ds.tmax))

    # --- 設定の探索（検証分割で選ぶ。試験分割は一切見ない）-----------------
    @printf("補間設定を探索: modes %s x eps %s x lambda %s\n",
            string(MODES), string(EPSILONS), string(LAMBDAS))
    t0 = time()
    best, grid, model = select_settings(ds.field, ds.mu, tr, va, inner;
                                        modes = MODES, epsilons = EPSILONS,
                                        lambdas = LAMBDAS, names = names)
    @printf("候補 %d 件を %.1f 分で評価\n", length(grid), (time() - t0) / 60)
    @printf("採用: modes=%d eps=%.3g lambda=%.3g\n\n",
            best.modes, best.epsilon, best.lambda)

    svals, ric = pod_spectrum(model)
    @printf("POD: 利用可能 %d 基底、採用 %d 基底、累積寄与率 %.6f\n",
            length(svals), best.modes, ric[best.modes])

    # --- 保持誤差 ---------------------------------------------------------
    rv = evaluate_accuracy(model, ds.field, ds.mu, va; names = names)
    rt = evaluate_accuracy(model, ds.field, ds.mu, te; names = names)
    rh = evaluate_accuracy(model, ds.field, ds.mu, vcat(va, te); names = names)
    println("\n=== 保持誤差（学習に用いていない分割）===")
    println("分割            n      MAE     RMSE   max|e|   L2[%]  L2上昇[%]")
    for (nm, r) in (("validation", rv), ("test", rt), ("holdout", rh))
        @printf("%-12s %4d %s\n", nm, r.n, fmt(r))
    end

    # --- 出力 -------------------------------------------------------------
    set_model_settings!(prov; pod_modes = best.modes,
                        rbf_settings = Dict{String,Any}(
                            "epsilon" => best.epsilon, "lambda" => best.lambda,
                            "ric_threshold" => best.ric_threshold,
                            "modes_grid" => MODES, "epsilon_grid" => EPSILONS,
                            "lambda_grid" => LAMBDAS,
                            "n_available_modes" => length(svals),
                            "selected_on" => "validation"))

    write_table(prov, "holdout_accuracy.tsv",
                ["split", "n", "tmax_mae", "tmax_rmse", "tmax_maxe",
                 "field_l2_rel_pct", "field_l2_rise_pct"],
                [[nm, r.n, r.tmax_mae, r.tmax_rmse, r.tmax_maxe, r.field_l2_rel, r.field_l2_rise]
                 for (nm, r) in (("validation", rv), ("test", rt), ("holdout", rh))])

    write_table(prov, "holdout_predictions.tsv",
                ["name", "split", "budget", "sum_sq", "max_cell", "tmax_fvm", "tmax_rom", "error"],
                [begin
                     rec = ds.records[i]
                     p = predict_tmax(model, @view ds.mu[:, i])
                     [rec.name, rec.split, rec.budget, rec.sum_sq, rec.max_cell,
                      ds.tmax[i], p, p - ds.tmax[i]]
                 end for i in vcat(va, te)])

    write_table(prov, "rbf_grid.tsv",
                ["modes", "epsilon", "lambda", "tmax_mae", "tmax_rmse", "tmax_maxe",
                 "field_l2_rel_pct", "field_l2_rise_pct"],
                [[g.modes, g.epsilon, g.lambda, g.tmax_mae, g.tmax_rmse, g.tmax_maxe,
                  g.field_l2_rel, g.field_l2_rise] for g in grid])

    write_table(prov, "pod_spectrum.tsv", ["mode", "singular_value", "cumulative_ric"],
                [[i, svals[i], ric[i]] for i in eachindex(svals)])

    # --- ベースライン比較（Req 1.3）---------------------------------------
    # 問うべきは「ROM が正確か」ではなく「はるかに単純なモデルに勝つか」である。
    #   const : 学習平均                （情報なし）
    #   count : Tmax = a + b N          （2 母数、配置を見ない）
    #   cells : Tmax = a + sum b_ij n_ij（17 母数、配置に線形）
    # cells に勝って初めて、非線形な代理モデルが要ることが示せる。
    nall = length(ds.records)
    Nvec = [Float64(r.budget) for r in ds.records]
    designs = ["const" => ones(nall, 1),
               "count" => hcat(ones(nall), Nvec),
               "cells" => hcat(ones(nall), permutedims(ds.mu))]
    score3(p, t) = (mean(abs.(p .- t)), sqrt(mean(abs2, p .- t)), maximum(abs.(p .- t)))
    println("\n=== ベースライン比較（Tmax の予測誤差）===")
    @printf("%-8s %6s %9s %9s %9s | %9s %9s %9s\n",
            "model", "母数", "val MAE", "val RMSE", "val max", "test MAE", "test RMSE", "test max")
    base_rows = Any[]
    mae_of = Dict{String,NTuple{2,Float64}}()
    for (nm, A) in designs
        b = A[tr, :] \ ds.tmax[tr]
        mv, rvv, xv = score3(A[va, :] * b, ds.tmax[va])
        mt, rtt, xt = score3(A[te, :] * b, ds.tmax[te])
        @printf("%-8s %6d %9.5f %9.5f %9.5f | %9.5f %9.5f %9.5f\n",
                nm, size(A, 2), mv, rvv, xv, mt, rtt, xt)
        push!(base_rows, [nm, size(A, 2), mv, rvv, xv, mt, rtt, xt])
        mae_of[nm] = (mv, mt)
    end
    @printf("%-8s %6d %9.5f %9.5f %9.5f | %9.5f %9.5f %9.5f\n", "ROM", best.modes,
            rv.tmax_mae, rv.tmax_rmse, rv.tmax_maxe, rt.tmax_mae, rt.tmax_rmse, rt.tmax_maxe)
    push!(base_rows, ["ROM", best.modes, rv.tmax_mae, rv.tmax_rmse, rv.tmax_maxe,
                      rt.tmax_mae, rt.tmax_rmse, rt.tmax_maxe])
    write_table(prov, "baseline_comparison.tsv",
                ["model", "n_param", "val_mae", "val_rmse", "val_maxe",
                 "test_mae", "test_rmse", "test_maxe"], base_rows)
    println()
    for nm in ("count", "cells")
        iv = (mae_of[nm][1] - rv.tmax_mae) / mae_of[nm][1] * 100
        it = (mae_of[nm][2] - rt.tmax_mae) / mae_of[nm][2] * 100
        @printf("ROM vs %-6s: validation %+.1f%%, test %+.1f%%%s\n", nm, iv, it,
                nm == "cells" ? "   <- 非線形な代理モデルが要るかの基準" : "")
    end

    path = save_rom(resolve_output(prov, "rom_model.jld2"), model)
    @printf("\n縮約モデルを保存: %s（%.2f GB）\n", path, filesize(path) / 2^30)

    # --- 完了条件: 再読み込みして同じ予測が得られること -------------------
    reloaded = load_rom(path)
    worst = 0.0
    for i in vcat(va, te)
        worst = max(worst, abs(predict_tmax(reloaded, @view ds.mu[:, i]) -
                               predict_tmax(model, @view ds.mu[:, i])))
    end
    @printf("再読み込みの一致: 最大差 %.3e K（%d 件）\n", worst, length(va) + length(te))
    worst == 0.0 || error("再読み込みした縮約モデルの予測が一致しない（最大差 $worst K）")

    # --- 配置効果の幅と合格判定（Req 2.1, 2.2）-----------------------------
    # 問うべきは「誤差が小さいか」ではなく「配置による差より十分小さいか」である。
    lv = budgets(ds)
    println("\n=== 配置効果の幅と合格判定 ===")
    @printf("しきい値 = 幅 x %.2f\n", CFG.accuracy_threshold_ratio)
    @printf("%5s %6s %11s %11s %9s %9s %9s %s\n",
            "N", "n", "Tmax最小", "Tmax最大", "幅[K]", "誤差[K]", "誤差/幅", "判定")
    judge_rows = Any[]
    for b in lv
        idx = budget_indices(ds, b)
        hidx = [i for i in idx if ds.records[i].split in ("validation", "test")]
        lo, hi = extrema(ds.tmax[idx])
        spread = hi - lo
        err = isempty(hidx) ? NaN :
              mean(abs(predict_tmax(model, @view ds.mu[:, i]) - ds.tmax[i]) for i in hidx)
        thr = spread * CFG.accuracy_threshold_ratio
        if isnan(err)
            @printf("%5d %6d %11.4f %11.4f %9.4f %9s %9s %s\n",
                    b, length(idx), lo, hi, spread, "-", "-", "保持ケースなし")
            push!(judge_rows, [b, length(idx), lo, hi, spread, NaN, thr, NaN, "no_holdout"])
            continue
        end
        verdict, warn, ratio = judge_accuracy(err, spread; tmax_threshold = thr)
        @printf("%5d %6d %11.4f %11.4f %9.4f %9.4f %9.4f %s\n",
                b, length(idx), lo, hi, spread, err, ratio, String(verdict))
        push!(judge_rows, [b, length(idx), lo, hi, spread, err, thr, ratio, String(verdict)])
        warn === nothing || record_warning!(prov, "N=$b: $warn")
    end
    write_table(prov, "placement_spread_judgment.tsv",
                ["budget", "n", "tmax_min", "tmax_max", "spread", "holdout_mae",
                 "threshold", "error_to_spread", "verdict"],
                judge_rows; scope = "per_budget")

    # --- 最適化性能（Req 2.5, 2.6）----------------------------------------
    # 順位相関: 縮約モデルが設計の優劣を正しく並べられるか
    # regret  : 縮約モデルが選んだ設計と、候補中の真の最良との差
    println("\n=== 最適化性能（保持ケースのみ）===")
    @printf("%8s %6s %10s %10s %10s\n", "範囲", "n", "順位相関", "regret[K]", "真の最良[K]")
    opt_rows = Any[]
    function opt_metrics(idx)
        p = [predict_tmax(model, @view ds.mu[:, i]) for i in idx]
        t = ds.tmax[idx]
        chosen = idx[argmin(p)]
        return (n = length(idx), rho = spearman(p, t),
                regret = ds.tmax[chosen] - minimum(t), best = minimum(t),
                chosen = ds.records[chosen].name)
    end
    hold_all = vcat(va, te)
    m = opt_metrics(hold_all)
    @printf("%8s %6d %10.4f %10.4f %10.4f\n", "全水準", m.n, m.rho, m.regret, m.best)
    push!(opt_rows, ["pooled", m.n, m.rho, m.regret, m.best, m.chosen])
    for b in lv
        idx = [i for i in hold_all if ds.records[i].budget == b]
        length(idx) >= 2 || continue
        mb = opt_metrics(idx)
        @printf("%8s %6d %10.4f %10.4f %10.4f\n", "N=$b", mb.n, mb.rho, mb.regret, mb.best)
        push!(opt_rows, ["N=$b", mb.n, mb.rho, mb.regret, mb.best, mb.chosen])
    end
    write_table(prov, "optimization_metrics.tsv",
                ["scope", "n", "spearman", "regret", "true_best_tmax", "chosen_case"],
                opt_rows; scope = "per_budget")

    write_text(prov, "build_rom_summary.txt", """
    データセット: $(CFG.dataset_id)
    ケース $(length(ds.records)) 件（train $(length(tr)) / validation $(length(va)) / test $(length(te))）
    内部格子: $(inner)

    採用した補間設定: modes=$(best.modes) epsilon=$(best.epsilon) lambda=$(best.lambda)
    利用可能な基底数: $(length(svals))、採用基底の累積寄与率: $(ric[best.modes])
    設定は validation 分割のみで選定した（test 分割は選定に用いていない）

    保持誤差
      validation  n=$(rv.n)  MAE=$(rv.tmax_mae) RMSE=$(rv.tmax_rmse) max=$(rv.tmax_maxe) L2=$(rv.field_l2_rel)%
      test        n=$(rt.n)  MAE=$(rt.tmax_mae) RMSE=$(rt.tmax_rmse) max=$(rt.tmax_maxe) L2=$(rt.field_l2_rel)%
      holdout     n=$(rh.n)  MAE=$(rh.tmax_mae) RMSE=$(rh.tmax_rmse) max=$(rh.tmax_maxe) L2=$(rh.field_l2_rel)%
    """)
    write_provenance(prov)
    write_warnings(prov)

    @printf("\n=== build_rom end %s（所要 %.1f 分）===\n",
            now(), (now() - started).value / 60000)
end

main()
