# Tasks: model-builder

## 1. 格子座標系の生成ロジックの実装 (P)
_Boundary: ModelBuilder.Grid_
- [x] 1.1 `ModelBuilder/Grid.jl` に、層境界マーカーと細分化ルール（pg_dpthオフセット）から 31 個の格子面を算出する機能を実装する。 [2.1]
  - オリジナルの `Zcase2!` と同一の座標値を生成すること。
- [x] 1.2 セル中心座標、セル幅、および外挿座標（ガイドセル用）を含む `CoordinateSystem` オブジェクトの構築機能を実装する。 [2.2]

## 2. 3D ID マップの充填ロジック
_Boundary: ModelBuilder.Main_
_Depends: 1.1, 1.2_
- [x] 2.1 `ModelBuilder/ModelBuilder.jl` に、指定された解像度（NXY+2, NXY+2, NZ+2）の ID 配列を初期化・管理する機能を実装する。 [2.2]
- [x] 2.2 オリジナルの順序（PG > TSV > Silicon > Bumps > Resin）に従い、各コンポーネントを `GeometryLogic` を用いて充填するメインループを実装する。 [1.2, 1.3, 3.1]
  - BBox に基づく走査範囲の最適化を適用し、計算効率を確保すること。

## 3. 物性値マップへの展開
_Boundary: ModelBuilder.Mapper_
_Depends: 2.1, 2.2_
- [x] 3.1 `ModelBuilder/Mapper.jl` に、ID マップから λ, ρ, Cp の 3D 配列を一括生成・充填する機能を実装する。 [3.3]
  - `ConfigLoader` から取得した物理定数を正確にマッピングすること。

## 4. 統合検証と回帰テスト
_Boundary: ModelBuilder.Tests_
_Depends: 1.1, 2.2, 3.1_
- [x] 4.1 ユニットテスト：生成された Z 座標ベクトルが `H2-main-original` の定数リストと完全に一致することを検証する。 [1.2]
- [x] 4.2 統合テスト：小規模な設定で、全 4 つの 3D 配列（ID, λ, ρ, Cp）が整合性を持って生成されることを検証する。 [1.1, 4.1]
