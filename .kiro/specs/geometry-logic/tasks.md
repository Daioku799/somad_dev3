# Tasks: geometry-logic

## 1. 幾何プリミティブ判定の実装 (P)
_Boundary: GeometryLogic.Primitives_
- [ ] 1.1 `GeometryLogic/Primitives.jl` に `is_included_rect` を実装する。 [1.1, 2.3]
  - `modelA.jl` のロジックを流用し、幾何学的な重なり体積計算（占有率 0.5 以上）を行うこと。
- [ ] 1.2 `GeometryLogic/Primitives.jl` に `is_included_cyl` を実装する。 [1.1, 2.3]
  - `modelA.jl` のロジックを流用し、`samples=50` によるサンプリング判定（占有率 0.5 以上）を行うこと。
- [ ] 1.3 `GeometryLogic/Primitives.jl` に `is_included_sph` を実装する。 [1.1, 2.3]
  - `modelA.jl` のロジックを流用し、`samples=50` によるサンプリング判定（占有率 0.5 以上）を行うこと。

## 2. GDS連携と統合判定の実装 (P)
_Boundary: GeometryLogic.GdsIntegration_
- [ ] 2.1 `GeometryLogic/GdsIntegration.jl` に `is_included_chip` を実装する。 [1.2, 2.4]
  - `GdsMapping.is_point_in_layer` を活用し、指定された Z 範囲内でチップ領域に含まれるか判定すること。

## 3. 高速化と公開APIの整備
_Boundary: GeometryLogic.Main_
_Depends: 1.1, 1.2, 1.3, 2.1_
- [ ] 3.1 `GeometryLogic/GeometryLogic.jl` に BBox 早期棄却ロジックを共通レイヤーとして実装する。 [2.2]
- [ ] 3.2 浮動小数点数誤差に対処するための Tolerance（1e-12m）を適用する。 [4.1]

## 4. テストと検証
_Boundary: GeometryLogic.Tests_
_Depends: 3.1_
- [ ] 4.1 ユニットテスト：各プリミティブが `H2-main-original` と同一の入力に対して同一の Bool 値を返すことを検証する。 [1.1, 2.3]
- [ ] 4.2 性能テスト：BBox 早期棄却の有効性を検証する。 [2.2]
- [ ] 4.3 境界テスト：判定の安定性を検証する。 [4.1]
