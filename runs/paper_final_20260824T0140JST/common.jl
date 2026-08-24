# 本 run の実行条件をここに一箇所へ集約する。
# 後続の全てのドライバはこのファイルからのみ条件を受け取り、各自で直書きしない。
# 別のデータセットに対して同じ解析を行うには、末尾の `CFG` の構築だけを書き換える。

using JSON
using JLD2

const ROOT = "/home/foo/somad_dev3"

for m in ("PipelineData", "PipelineReport", "PipelineROM", "ObjectiveMetrics")
    isdefined(Main, Symbol(m)) && continue
    include(joinpath(ROOT, "H2-rom", "src", m, "$(m).jl"))
end
using .PipelineData
using .PipelineReport
using .PipelineROM
using .ObjectiveMetrics

"""
    PipelineConfig

解析全体で用いる条件。研究条件をドライバのソースに埋め込まないための単一の入り口。
"""
struct PipelineConfig
    # --- データの所在 ---
    dataset_id::String
    run_dir::String
    support_run_dir::String          # 補助データセット（境界条件感度・線形性）
    support_plan_name::String
    support_snapshot_name::String

    # --- 設計空間 ---
    train_budgets::Vector{Int}       # 学習水準
    interp_budgets::Vector{Int}      # 内挿テスト水準
    sweep_budgets::Vector{Int}       # 最適化で走査する本数

    # --- 判定の基準値 ---
    accuracy_threshold_ratio::Float64  # 合格しきい値 = 配置効果の幅 x この比
    max_abs_spearman::Float64          # 第3目的の独立性の上限
    max_error_ratio::Float64           # 第3目的の予測誤差の許容比（幅に対する）
    generalization_warn_factor::Float64  # 汎化検証の警告倍率

    # --- 探索と統計 ---
    n_restart::Int                   # 探索のリスタート数
    learning_curve_seeds::Int        # 学習曲線の試行数
    learning_curve_sizes::Vector{Int}
    epsilon_levels::Int              # ε制約法の刻み数

    # --- 乱数 ---
    seed_learning_curve::Int
    seed_search::Int
end

"""本 run のデータセットを読み込む。"""
load_main(cfg::PipelineConfig) = load_dataset(DatasetSpec(run_dir = cfg.run_dir))

"""補助データセットを読み込む。計画情報とスナップショット名が本番と異なる。"""
load_support(cfg::PipelineConfig) = load_dataset(DatasetSpec(
    run_dir = cfg.support_run_dir,
    plan_name = cfg.support_plan_name,
    snapshot_name = cfg.support_snapshot_name))

"""来歴を初期化する。乱数指定はここで登録する。"""
function make_provenance(cfg::PipelineConfig, ds::LoadedDataset)
    prov = RunProvenance(run_dir = cfg.run_dir,
                         dataset_id = cfg.dataset_id,
                         n_cases = length(ds.records),
                         split_counts = split_counts(ds))
    record_seed!(prov, "learning_curve", cfg.seed_learning_curve)
    record_seed!(prov, "search", cfg.seed_search)
    return prov
end


"""
格子間隔を代表ケースから読み取る。x・y は等間隔だが z は層構成に従って
等間隔ではないため、スナップショットの z 座標をそのまま用いる。
"""
function load_geometry(cfg::PipelineConfig, ds::LoadedDataset)
    case_dir = joinpath(cfg.run_dir, "cases", first(ds.records).name)
    conf = JSON.parsefile(joinpath(case_dir, "config.json"))
    snap = jldopen(joinpath(case_dir, ds.spec.snapshot_name), "r") do d
        (z = d["z_centers"], nx = d["nx"], ny = d["ny"])
    end
    return GridGeometry(dx = conf["lx"] / snap.nx,
                        dy = conf["ly"] / snap.ny,
                        z_centers = snap.z[2:end-1])   # ゴーストを除く
end

"""走査対象の本数を、学習水準の範囲内に限定する。"""
function valid_sweep_budgets(cfg::PipelineConfig)
    lo, hi = extrema(cfg.train_budgets)
    return filter(b -> lo <= b <= hi, cfg.sweep_budgets)
end

# ---------------------------------------------------------------------------
# 本 run の条件。別のデータセットに切り替えるにはここだけを書き換える。
# ---------------------------------------------------------------------------
const CFG = PipelineConfig(
    "paper_final_20260824T0140JST",
    joinpath(ROOT, "runs", "paper_final_20260824T0140JST"),
    joinpath(ROOT, "runs", "fig_support_20260824T0040JST"),
    "plan.json",
    "snapshot_g240.jld2",

    [36, 48, 60],
    [42, 54],
    collect(36:60),

    0.2,      # 合格しきい値は配置効果の幅の 1/5
    0.7,      # 独立性: |Spearman| < 0.7
    0.2,      # 予測可能性: 誤差 < 幅の 1/5
    2.0,      # 汎化検証: 学習水準の誤差の 2 倍を超えたら警告

    400,      # 探索のリスタート数
    5,        # 学習曲線の試行数
    [20, 40, 60, 100, 150, 200, 250, 300],
    10,       # ε制約法の刻み数

    20260824,
    4242,
)
