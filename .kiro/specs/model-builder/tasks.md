# Tasks: model-builder

## 1. オリジナル準拠の格子座標生成 (P)
_Boundary: ModelBuilder.Grid_
- [ ] 1.1 `ModelBuilder/Grid.jl` に、`ConfigLoader` の動的マーカーを用いてオリジナルの `Zcoord.jl` ロジックを実行し、`Z`, `z_centers`, `dz_grid` を生成する機能を実装する。 [2.1, 2.2]
- [ ] 1.2 生成された Z 座標配列（nk+3）がオリジナルと数値的に一致することを検証するテストを作成する。 [1.2]

## 2. 統合モデル構築（modelA.jl の再編）
_Boundary: ModelBuilder.Main_
_Depends: 1.1_
- [ ] 2.1 `H2-main-copy/src/modelA.jl` を新アーキテクチャのフロントエンドとしてリファクタリングし、`fillID!` を外部モジュール連携版に置き換える。 [1.1]
- [ ] 2.2 オリジナルの順序（PG > TSV > Silicon > Solder > Resin）を厳守した ID 充填ループを実装する。 [1.2, 1.3, 3.1]
  - プリミティブにはオリジナルの判定関数、チップには GDS 判定を使用。

## 3. 物性値マッピングの実装 (P)
_Boundary: ModelBuilder.Mapper_
_Depends: 2.2_
- [ ] 3.1 `ConfigLoader` の定数に基づき、ID マップから物性値マップ（λ, ρ, Cp）を構築する `setProperties!` を再実装する。 [3.3]

## 4. 最終的な統合テスト
_Boundary: ModelBuilder.Tests_
_Depends: 3.1_
- [ ] 4.1 オリジナルと同一パラメータでの ID マップの完全一致テストを実行し、1ビットの差異もないことを検証する。 [1.2, 4.1]
