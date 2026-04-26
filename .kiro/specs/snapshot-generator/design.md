# Technical Design: Snapshot Generator

## 1. システム構成と技術スタック

Snapshot Generatorは、ROM（次数低減モデル）の構築に必要なトレーニングデータ（スナップショット）を効率的に収集するためのオーケストレーション層です。

### 技術スタック
- **言語**: Julia 1.10+
- **サンプリング**: `LatinHypercubeSampling.jl`
  - 設計変数の空間を効率的に網羅するために使用。
- **データ保存**: `JLD2.jl`
  - Juliaの型情報を保持したまま高速にI/Oを行うために採用。
- **シリアル化**: `JSON3.jl`
  - `manifest.json` および `config.json` の読み書きに使用。
- **並列制御**: `Distributed` (Julia標準ライブラリ) または `Base.Threads`
  - 複数ケースの同時実行を制御。

---

## 2. オーケストレーション（実行制御）

シミュレーションの実行は、各ケースごとに独立した作業ディレクトリを作成して行います。

### 実行フロー
1. **パラメータ生成**: `LatinHypercubeSampling.jl` を用いて、指定された範囲内で $N$ 個のパラメータセットを生成。
2. **ディレクトリ作成**: `data/work/case_{id}/` を作成。
3. **設定ファイル配置**: 生成したパラメータに基づき、`model-builder` が解釈可能な `config.json` を各ディレクトリに配置。
4. **ソルバー実行**: 
   - `H2-main-ext/run.jl` を外部プロセスとして実行。
   - `JULIA_LOAD_PATH` を適切に設定し、ソースコードを共有。
   - 実行時引数または環境変数で「スナップショット出力先」を指定。
5. **ポストプロセス**: 実行完了後、生成された `log.txt` を確認し、収束状況を判定。

### 並列実行戦略
- ユーザー設定により、同時実行数 `max_workers` を指定可能にする。
- 各ソルバー実行がマルチスレッド（`JULIA_NUM_THREADS`）を使用する場合、`max_workers * threads_per_case <= total_cores` となるよう制御。

---

## 3. データモデル

### 3.1 `manifest.json` (メタデータ管理)
全ケースの状態とパラメータを一覧管理します。

```json
{
  "project": "H2-ROM-Snapshots",
  "generated_at": "2023-10-27T10:00:00",
  "parameter_space": {
    "r_tsv": [10e-6, 50e-6],
    "n_tsv": [1, 16],
    "bounds_x": [0.0, 1.0],
    "bounds_y": [0.0, 1.0]
  },
  "cases": [
    {
      "id": "case_0001",
      "status": "success",
      "params_normalized": [0.1, 0.5, ...],
      "params_physical": {
        "r_tsv": 15e-6,
        "n_tsv": 4,
        "positions": [[0.2, 0.2], [0.2, 0.8], [0.8, 0.2], [0.8, 0.8]]
      },
      "snapshot_path": "data/raw/snapshot_case_0001.jld2",
      "runtime_sec": 45.2,
      "iterations": 120
    }
  ]
}
```

### 3.2 `.jld2` (スナップショットデータ)
各ケースの計算結果をバイナリ形式で保存します。

- `theta`: `Array{Float64, 3}` (3次元温度場 $\theta$)
- `params`: `NamedTuple` (物理パラメータ)
- `grid_info`: `Dict` (格子解像度、座標系)
- `convergence`: `Bool` (収束フラグ)

---

## 4. エラーハンドリングとロギング

シミュレーションは長時間に及ぶため、一部の失敗で全体を止めない堅牢な設計とします。

- **タイムアウト**: 各ケースに `timeout_sec` を設定。超過した場合はプロセスを kill し、`manifest.json` に `timeout` と記録。
- **非収束**: ソルバーが最大反復回数に達しても収束しなかった場合、`status: non-converged` として記録。スナップショット自体は（参考値として）保存するか、フラグで制御可能にする。
- **ログ収集**: 各ケースの `stdout`/`stderr` は `data/work/case_{id}/output.log` にリダイレクトし、デバッグを容易にする。

---

## 5. `H2-main-ext` への統合計画

`heat3ds.jl` を修正し、シミュレーション完了後にデータを自動保存する機能を追加します。

### 修正内容
1. `q3d` 関数の引数に `snapshot_path::String=""` を追加。
2. 計算終了後、`snapshot_path` が空でなければ `JLD2.save` を実行。

```julia
# heat3ds.jl の修正イメージ
function q3d(..., snapshot_path="")
    # ... シミュレーション実行 ...
    if !isempty(snapshot_path)
        using JLD2
        save(snapshot_path, "theta", wk.θ, "params", config_params, ...)
    end
end
```

3. `run.jl` に `--snapshot PATH` オプションを追加し、コマンドラインから出力先を制御可能にする。

---

## 6. ディレクトリ構造

```text
.kiro/specs/snapshot-generator/
├── requirements.md
└── design.md (This file)

src/SnapshotGenerator/
├── Runner.jl       # プロセスオーケストレーション
├── Sampler.jl      # LHSパラメータ生成
└── Manifest.jl     # メタデータ管理

data/
├── raw/            # 最終的な .jld2 スナップショット
└── work/           # 実行時の一時ディレクトリ
```
