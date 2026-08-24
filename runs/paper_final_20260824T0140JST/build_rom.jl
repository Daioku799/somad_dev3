# 縮約モデルの構築と保持誤差の評価（Req 1.1, 1.2）
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
