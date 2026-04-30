# Research Log: validation-plot

## Summary
スナップショットファイル（JLD2）からのデータ抽出と、材料分布および温度分布のサイドバイサイドプロット機能の追加に向けた調査。

## Research Log Topics

### 1. レガシー配色の特定
- **Source**: `H2-main_TSV_Opt/src/plotter.jl`
- **Findings**:
  - `plot_heatsource_tsv_overlay_nu` 関数内で `custom_palette = [:yellow, :gray, :purple, :orange, :blue, :green, :red]` が定義されている。
  - 材料IDのマッピング: 1:TSV(Yellow/Orange), 2:Si(Gray), 3:Solder, 4:FR4, 5:Aluminum, 6:Resin, 7:PG(Red)。
  - `heatmap` の `clims=(0.5, 7.5)` を使用してIDを色に固定。

### 2. JLD2スナップショット構造
- **Source**: `data/raw/snapshot_13.jld2`
- **Findings**:
  - キー: `["nz", "theta", "nx", "id_map", "lambda", "ny", "z_faces", "config_summary", "z_centers"]`
  - `id_map`: `Array{UInt8, 3}`, (242, 242, 33)
  - `theta`: `Array{Float64, 3}` (温度場)
  - `z_centers`: `Vector{Float64}` (非一様格子のZ座標)

### 3. サイドバイサイドプロットの実装方法
- **Source**: `Plots.jl` ドキュメント
- **Findings**:
  - `plot(p1, p2, layout=(1, 2))` で簡単に横並び表示が可能。
  - カラーバーの共有やリンクも可能だが、ID（離散）と温度（連続）では個別にカラーバーを持つのが適切。

## Architecture Pattern Evaluation
- **Pattern**: Existing Module Extension
- **Decision**: `ValidationPlot` モジュールに `Snapshot.jl` を追加し、`plot_snapshot_validation` を実装する。
- **Rationale**: 断面抽出（Slicer）ロジックを共有でき、検証機能として一貫性を保てるため。

## Design Decisions
- **Generalization**: プロット用パレット定義を `Palettes.jl` として独立させ、モデル構築時とスナップショット時の両方で利用可能にする。
- **Simplification**: GDSオーバーレイ機能は要件から除外されたため、スナップショットプロットからは削除する。
- **Build vs Adopt**: スナップショットの読み込みには標準的な `JLD2.jl` を使用。

## Risks and Mitigations
- **Risk**: スナップショットによってIDの定義が異なる可能性。
- **Mitigation**: 共通の `MaterialID` 定数を定義し、スナップショット生成時とプロット時で一貫性を保証する。
- **Risk**: 温度スケールの統一。
- **Mitigation**: プロット関数に `temp_lims`（デフォルト値あり）を渡し、明示的にスケールを固定できるようにする。
