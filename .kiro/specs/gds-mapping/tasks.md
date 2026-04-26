# Tasks: gds-mapping

## 1. 基礎データ構造と幾何バリデーションの実装 (P)
_Boundary: GdsMapping.Types, GdsMapping.Validator_
- [ ] 1.1 `GdsMapping/Types.jl` に `GdsPolygon` および `GdsLayer` 構造体を定義する。 [3.1]
  - 頂点リストとBBoxを不変構造体として保持すること。
- [ ] 1.2 `GdsMapping/Validator.jl` にポリゴンの品質保証ロジックを実装する。 [2.1, 2.2, 2.3]
  - 閉路補完、重複頂点除去（1e-12m精度）、縮退チェックを含むこと。

## 2. GDSIIデータのロードと変換ロジック
_Boundary: GdsMapping.Main_
_Depends: 1.1, 1.2_
- [ ] 2.1 `SimpleGDS.jl` を用いてGDSIIファイルを読み込み、単位変換（um -> m）を適用する機能を実装する。 [1.1, 1.2]
- [ ] 2.2 読み込んだポリゴン群を検証・正規化し、`GdsLayer` オブジェクトを構築する `load_gds_layer` 関数を実装する。 [1.3, 3.1]
- [ ] 2.3 読み込まれたポリゴンが `config.json` のチップ範囲を逸脱している場合に警告を出すロジックを実装する。 [2.4]

## 3. 点包含判定とプロット用エクスポートの実装 (P)
_Boundary: GdsMapping.Query_
_Depends: 2.2_
- [ ] 3.1 BBoxによる早期棄却と `PolygonOps.inpolygon` (判定値 >= 0.5) を組み合わせた包含判定関数 `is_point_in_layer` を実装する。 [3.2, 3.3]
- [ ] 3.2 プロット用に全ポリゴンの頂点座標を Matrix 形式の配列としてエクスポートする `get_plot_data` 関数を実装する。 [4.1]

## 4. テストと検証
_Boundary: GdsMapping.Tests_
_Depends: 3.1, 3.2_
- [ ] 4.1 ユニットテスト：不良なGDSデータ（未閉路、重複頂点）が正しく正規化されることを検証する。 [2.1, 2.3]
- [ ] 4.2 ユニットテスト：境界線上および頂点上での内外判定が一貫していることを検証する。 [3.2]
- [ ] 4.3 ユニットテスト：`get_plot_data` がプロットモジュールに適したデータ形式を返すことを検証する。 [4.1]
