# Tasks: validation-plot

## 1. 断面抽出ユーティリティの実装 (P)
_Boundary: ValidationPlot.Slicer_
- [x] 1.1 `ValidationPlot/Slicer.jl` に、指定された物理座標（mm）に最も近い格子インデックス（i, j, k）を算出する機能を実装する。 [1.1]
  - 非一様格子の `z_centers` を考慮して正確に特定すること。
- [x] 1.2 3D 配列から指定されたインデックスの 2D スライス（XY, YZ面）を抽出する機能を実装する。 [1.1]

## 2. コアレンダラーの実装 (P)
_Boundary: ValidationPlot.Renderers_
- [x] 2.1 素材 ID ごとの固定カラーパレット（TSV=黄, Si=灰, Solder=紫, Sub=水色, HS=青, Resin=緑, PG=赤）を定義する。 [2.1]
- [x] 2.2 `Plots.jl` を用い、物理寸法（mm）を軸とした材料分布ヒートマップの描画機能を実装する。 [1.2, 2.1]
- [x] 2.3 温度分布データ（Float64）に対し、`thermal` カラーマップを用いた断面等高線図の描画機能を実装する。 [2.2]

## 3. GDS重ね書き機能の実装
_Boundary: ValidationPlot.Renderers_
_Depends: 2.2_
- [x] 3.1 `GdsMapping.get_plot_data` から取得したポリゴン頂点リストを、ヒートマップ上に線画（Outline）として重ねる機能を実装する。 [3.1]
  - 視覚的なズレを確認できるよう、対比しやすい色（白または黒）を使用すること。 [3.2]

## 4. 自動プロット生成とAPIの統合
_Boundary: ValidationPlot.Main_
_Depends: 1.1, 2.2, 3.1_
- [x] 4.1 `config.json` の `plots` セクションからスライス座標を取得し、一括で画像を生成・保存するメイン API を実装する。 [1.1, 4.1]
  - 出力ディレクトリの自動作成機能を含むこと。 [4.1]

## 5. テストと視覚的検証
_Boundary: ValidationPlot.Tests_
_Depends: 4.1_
- [x] 5.1 ユニットテスト：`Slicer` が境界付近の座標に対して正しいインデックスを返すことを検証する。 [1.1]
- [x] 5.2 統合テスト：実際にテスト用の `config.json` を用いて、全断面の PNG 画像が正常に出力されることを確認する。 [4.1]
