# Tasks: component-generator

## 1. 基礎データ構造とマスター座標生成の実装 (P)
_Boundary: ComponentGenerator.Types, ComponentGenerator.Layout_
- [x] 1.1 `ComponentGenerator/Types.jl` に幾何形状オブジェクト（`GeometryObject`）の構造体を定義する。 [3.1]
  - `type` (:cylinder, :sphere, :box), `pos`, `dims`, `mat_id` を含めること。
- [x] 1.2 `ComponentGenerator/Layout.jl` に、全チップ層で共通して利用される (x, y) 座標リストを生成する機能を実装する。 [1.1, 1.2, 1.3]
  - `manual` モード時は JSON から抽出、`random` モード時はシード値に基づき一意に生成すること。

## 2. コンポーネントスタックの構築と安全半径の適用
_Boundary: ComponentGenerator.Main_
_Depends: 1.1, 1.2_
- [x] 2.1 共通座標リストに基づき、各シリコン層（zm2-4, 5-7, 8-10）を貫通する TSV オブジェクトを生成するロジックを実装する。 [1.1]
- [x] 2.2 共通座標リストに基づき、各アンダーフィル層の中心 Z 座標に配置されるはんだバンプオブジェクトを生成するロジックを実装する。 [2.1]
- [x] 2.3 安全半径公式 $R = \sqrt{r_{tsv}^2 + (d_{ufill}/2)^2}$ を計算し、全てのはんだバンプオブジェクトの寸法として適用する機能を実装する。 [2.2]

## 3. 物理バリデーションの実装 (P)
_Boundary: ComponentGenerator.Validator_
_Depends: 2.1, 2.2_
- [x] 3.1 生成された全てのコンポーネントが `config.json` で定義されたチップ境界内に収まっているか検証する機能を実装する。 [4.1]
- [x] 3.2 TSV 中心間の距離を算出し、互いに干渉（$dist < 2 \times r_{tsv}$）していないか検証する機能を実装する。 [4.2]

## 4. テストと検証
_Boundary: ComponentGenerator.Tests_
_Depends: 2.3, 3.2_
- [x] 4.1 ユニットテスト：TSV とバンプの (x, y) 座標が全層で完全に一致（垂直同期）しているか検証する。 [1.1, 2.1]
- [x] 4.2 ユニットテスト：意図的に干渉させた座標セットを与えた際に、正しくバリデーションエラーが発生することを検証する。 [4.2]
- [x] 4.3 ユニットテスト：算出されたバンプ半径が安全半径公式の結果と一致することを検証する。 [2.2]
