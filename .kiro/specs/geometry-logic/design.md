# Technical Design: geometry-logic

## 1. System Architecture & Component Design

### 1.1 GeometryLogic モジュール
各幾何形状に対する「セル占有判定」を提供する数学カーネル集。

- `is_included_box(c1, c2, b1, b2)`: 軸平行直方体の判定。
- `is_included_cylinder(c1, c2, center, radius, zmin, zmax; samples=50)`: 円柱の判定。
- `is_included_sphere(c1, c2, center, radius; samples=50)`: 球体の判定。
- `is_included_gds(c1, c2, layer, zmin, zmax; samples=5)`: `GdsLayer` を用いた判定。

### 1.2 データ形式
- `c1, c2`: セルの最小/最大座標 `(x, y, z)` のタプル。
- 戻り値: `Bool` (占有率 0.5 以上なら true)。

## 2. Architecture Decisions & Integration

### 2.1 オリジナルロジックの移植 (Traceability: 1.1, 2.3)
`H2-main-original` の `modelA.jl` (lines 220-310) に記述されている数式を Julia の独立した関数として実装する。

### 2.2 GDSとの統合 (Traceability: 1.2, 2.4)
`GdsMapping.is_point_in_layer` を内部でサンプリングループ（デフォルト 5x5）から呼び出し、XY 平面の占有率を算出する。

### 2.3 高速化 (Traceability: 2.2)
全関数において、サンプリング実行前に `c1, c2` と `shape_bbox` の重なりチェックを行う。完全に外側なら即座に `false` を返す。

## 3. Boundary Commitments
- **Owned**: セル占有率判定ロジック、幾何サンプリング、BBoxフィルタリング。
- **Not Owned**: 優先順位の管理、3Dマップの構築（`model-builder`が担当）。

## 4. File Structure Plan
- `src/GeometryLogic/GeometryLogic.jl`: 公開API。
- `src/GeometryLogic/Primitives.jl`: 直方体、円柱、球の判定ロジック。
- `src/GeometryLogic/GdsIntegration.jl`: GDSポリゴンとZ範囲の統合判定。

## 5. Testing Strategy
- **Unit Tests**:
  - 各プリミティブが既知の座標（完全包含、完全除外、境界上）で正しく判定されるか。
  - サンプリング数が判定結果（50%閾値付近）に与える影響の確認。
  - 既存の `is_included_rect` 等と同一の入力に対して同一の結果を返すか。
