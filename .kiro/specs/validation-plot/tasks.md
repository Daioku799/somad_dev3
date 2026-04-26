# Tasks: validation-plot

## 1. 断面抽出ユーティリティの実装 (P)
_Boundary: ValidationPlot.Slicer_
- [ ] 1.1 `ValidationPlot/Slicer.jl` に、物理座標から格子インデックスを算出する機能を実装する。 [1.1]
- [ ] 1.2 3D 配列から XY, YZ 面のスライスを抽出する機能を実装する。 [1.1]

## 2. 素材 ID ヒートマップの実装 (P)
_Boundary: ValidationPlot.Renderers_
- [ ] 2.1 オリジナルの色使い（TSV=黄, Solder=紫等）を模したカラーパレットを定義する。 [2.1]
- [ ] 2.2 `Plots.jl` を用い、物理寸法（mm）を軸とした材料分布図を描画する。 [1.2, 2.1]

## 3. GDS重ね書きと自動保存
_Boundary: ValidationPlot.Main_
_Depends: 2.2_
- [ ] 3.1 `GdsMapping` の頂点データをヒートマップ上に重ねて描画する機能を実装する。 [3.1]
- [ ] 3.2 XY, YZ 断面の画像を自動生成して保存するメイン API を実装する。 [4.1]

## 4. テストと視覚的検証
_Boundary: ValidationPlot.Tests_
_Depends: 3.2_
- [ ] 4.1 統合テスト：テスト用 JSON を用いて、実際に PNG 画像が出力されることを確認する。 [4.1]
