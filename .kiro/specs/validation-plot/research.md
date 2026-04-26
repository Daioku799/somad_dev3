# Research Log: validation-plot

## Summary
`Plots.jl` を用いて、格子データ（IDマップ）と生データ（GDS頂点）を正確に重ね合わせる手法を調査した。XYプロットにおいては `heatmap` と `plot! (path)` の組み合わせが有効であり、YZプロットにおいては非一様格子の Z 座標ベクトルを用いた正確なアスペクト比の維持が重要であることを確認した。

## Research Log Topics

### Topic 1: GDSデータの重ね書き手法
- **Findings**:
  - `GdsMapping.get_plot_data` が返す `Vector{Matrix{Float64}}` は、一つの要素が一つの閉じられたポリゴンに対応する。
  - これを `plot!(mat[:,1], mat[:,2], seriestype=:path, linecolor=:white)` とすることで、ヒートマップの上に境界線を白抜きで描画できる。
  - スケーリングを合わせるため、`heatmap` の軸にも物理座標（mm）を適用する必要がある。

### Topic 2: 断面抽出の精度
- **Findings**:
  - ユーザーが JSON で指定する物理座標（例: Z=0.198mm）に対し、`Grid.find_k` 相当のロジックを用いて、最も近い格子点を選択する。
  - 非一様格子の場合、セル中心（Z-centers）に基づいてインデックスを特定するのが物理的に正しい。

## Architecture Decisions

### Decision 1: `config.json` へのプロット設定の統合
- **Rationale**: 断面位置をコードにハードコードせず、設定ファイルで一元管理することで、解析条件に応じた自動検証を容易にする。

### Decision 2: 素材 ID ごとの静的パレット定義
- **Rationale**: どのプロットを見ても「黄色はTSV」と直感的に理解できるように、モジュール定数としてカラーマップを固定する。

## Risks & Mitigations
- **Risk**: 大規模な GDS ポリゴン（数千個）を重ね書きする際の描画速度低下。
- **Mitigation**: プロット対象のレイヤーを限定し、必要に応じて BBox 範囲内のポリゴンのみをレンダリングする。
