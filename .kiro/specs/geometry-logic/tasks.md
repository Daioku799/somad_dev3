# Tasks: geometry-logic

## 1. 幾何プリミティブ判定の実装 (P)
_Boundary: GeometryLogic.Primitives_
- [x] 1.1 `GeometryLogic/Primitives.jl` に `is_included_box` を実装する。 [1.1, 2.3]
  - 幾何学的に厳密な重なり体積計算（占有率 0.5 以上）を行うこと。
- [x] 1.2 `GeometryLogic/Primitives.jl` に `is_included_cylinder` を実装する。 [1.1, 2.3]
  - `samples=50` によるサンプリング判定（占有率 0.5 以上）を行うこと。
- [x] 1.3 `GeometryLogic/Primitives.jl` に `is_included_sphere` を実装する。 [1.1, 2.3]
  - `samples=50` によるサンプリング判定（占有率 0.5 以上）を行うこと。

## 2. GDS連携と統合判定の実装 (P)
_Boundary: GeometryLogic.GdsIntegration_
- [x] 2.1 `GeometryLogic/GdsIntegration.jl` に `is_included_gds` を実装する。 [1.2, 2.4]
  - `GdsMapping.is_point_in_layer` を 5x5 サンプリングで呼び出し、Z軸方向の重なり比率と組み合わせて占有率を算出すること。

## 3. 高速化と公開APIの整備
_Boundary: GeometryLogic.Main_
_Depends: 1.1, 1.2, 1.3, 2.1_
- [x] 3.1 `GeometryLogic/GeometryLogic.jl` に BBox 早期棄却ロジックを共通レイヤーとして実装する。 [2.2]
  - 全ての判定関数の冒頭で実行され、不要なサンプリングを回避すること。
- [x] 3.2 浮動小数点数誤差に対処するための Tolerance（1e-12m）を全ての比較演算に適用する。 [4.1]

## 4. テストと検証
_Boundary: GeometryLogic.Tests_
_Depends: 3.1_
- [x] 4.1 ユニットテスト：各プリミティブが `H2-main-original` と同一の入力に対して同一の Bool 値を返すことを検証する。 [1.1, 2.3]
- [x] 4.2 性能テスト：BBox 早期棄却により、形状外のセル判定が高速（サンプリングなし）に行われることを検証する。 [2.2]
- [x] 4.3 境界テスト：セルが形状の境界に完全一致する場合の判定の安定性を検証する。 [4.1]
