# Tasks: component-generator

## 1. 基礎データ構造とマスター座標生成の実装 (P)
_Boundary: ComponentGenerator.Types, ComponentGenerator.Layout_
- [ ] 1.1 `ComponentGenerator/Types.jl` に幾何形状オブジェクト（`GeometryObject`）の構造体を定義する。 [3.1]
  - `type` (:cylinder, :sphere, :box), `pos`, `dims`, `mat_id` を含めること。
- [ ] 1.2 `ComponentGenerator/Layout.jl` に、全チップ層で共通して利用される (x, y) 座標リストを生成する機能を実装する。 [1.1, 1.2, 1.3]
  - `manual` モード時は JSON から抽出、`random` モード時はシード値に基づき一意に生成すること。

## 2. コンポーネントスタックの構築と物理モデルの適用
_Boundary: ComponentGenerator.Main_
_Depends: 1.1, 1.2_
- [ ] 2.1 共通座標リストに基づき、各シリコン層（zm2-4, 5-7, 8-10）を貫通する TSV オブジェクトを生成するロジックを実装する。 [1.1]
- [ ] 2.2 共通座標リストに基づき、各アンダーフィル層（zm1-2, 4-5, 7-8, 10-11）に配置されるはんだバンプオブジェクトを生成する。 [2.1]
- [ ] 2.3 `r_bump` および `r_tsv` を `ModelConfig` から取得し、生成されたオブジェクトに適用する。 [2.2]

## 3. 物理バリデーションの実装 (P)
_Boundary: ComponentGenerator.Validator_
_Depends: 2.1, 2.2_
- [ ] 3.1 生成されたコンポーネントがチップ境界内に収まっているか検証する機能を実装する。 [4.1]
- [ ] 3.2 TSV 同士の干渉を検証する機能を実装する。 [4.2]

## 4. テストと検証
_Boundary: ComponentGenerator.Tests_
_Depends: 2.3, 3.2_
- [ ] 4.1 ユニットテスト：TSV とバンプの垂直同期（座標の一致）を検証する。 [1.1, 2.1]
- [ ] 4.2 ユニットテスト：干渉チェックのバリデーションを検証する。 [4.2]
- [ ] 4.3 ユニットテスト：オリジナルと同一のパラメータで同一のオブジェクトリストが生成されることを検証する。 [2.2]
