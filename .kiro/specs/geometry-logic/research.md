# Research Log: geometry-logic

## Summary
`H2-main-original` の幾何判定ロジックを精査し、単なる点判定ではなく「セルの占有率（50%閾値）」に基づいた判定が解析モデルの幾何学的精度を支えていることを確認した。本モジュールでは、これらの数式とサンプリング手法を忠実に継承しつつ、GDSII 判定を同等の精度で統合する。

## Research Log Topics

### Topic 1: オリジナル判定関数の仕様
- **Findings**:
  - `is_included_rect`: 解析解（重なり体積の算出）を用いている。
  - `is_included_cyl/sph`: `samples=50` によるモンテカルロ的サンプリング（合計 125,000点）を用いている。
  - いずれも「占有率 0.5 以上」を `true` としている。

### Topic 2: GDS判定のサンプリング方針
- **Findings**:
  - `H2-main_TSV_Opt` では `is_included_gds` において XY 平面を `samples=5`（計25点）でサンプリングし、それに Z 方向の重なり比率を乗じている。
  - プリミティブ（samples=50）に比べて低解像度だが、2Dポリゴン判定の負荷を考慮した現実的な選択である。本設計でもこの方針を継承する。

## Architecture Decisions

### Decision 1: セルベース判定インターフェースの採用
- **Rationale**: `model-builder` が格子点（セルの中心）だけでなく、セルの広がりを考慮したモデル構築を行うため、全ての判定関数はセルの境界 $(c1, c2)$ を受け取る形式とする。

### Decision 2: 浮動小数点数誤差への対処 (Tolerance)
- **Rationale**: 格子境界と形状境界が完全に一致する場合の不安定さを防ぐため、`1e-12` 程度の許容誤差を考慮した比較演算を行う。

## Risks & Mitigations
- **Risk**: サンプリング（50^3）による計算時間の増大。
- **Mitigation**: BBox による早期棄却を全関数に実装し、無駄なサンプリングループを回避する。
