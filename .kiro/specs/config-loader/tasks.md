# Tasks: config-loader

## 1. 基礎データ構造と定数の定義 (P)
_Boundary: ConfigLoader.Types, ConfigLoader.Defaults_
- [ ] 1.1 `ConfigLoader/Types.jl` に解析用設定を保持する不変構造体（`Material`, `Layer`, `TSVConfig`, `ModelConfig`）を定義する。 [2.1]
- [ ] 1.2 `ConfigLoader/Defaults.jl` に `H2-main-original` 由来の定数群を定義し、試験用設定を生成する `generate_test_config()` を実装する。 [1.3]

## 2. JSON設定ファイルのパースと厳格な検証
_Boundary: ConfigLoader.Main_
_Depends: 1.1, 1.2_
- [ ] 2.1 `config.json` および `tsv_config.json` を読み込み、必須項目の欠落をチェックして `ModelConfig` を生成する機能を実装する。 [1.1, 1.2]
  - 自動補完を行わず、項目欠落時はエラーを出力すること。
- [ ] 2.2 物理定数（熱伝導率 λ 等）が 0 以下の数値である場合にバリデーションエラーを通知する機能を実装する。 [2.2]

## 3. 座標計算ロジックの実装 (P)
_Boundary: ConfigLoader.Calculators_
_Depends: 1.1_
- [ ] 3.1 `layers` 配列から累積Z座標マーカー（`zm0`〜`zm12`）を算出するロジックを実装する。 [3.1]
- [ ] 3.2 Silicon層の上面から `pg_dpth` オフセットされた PowerGrid 用のZ座標を算出する機能を実装する。 [3.2]
- [ ] 3.3 はんだバンプの推奨半径（`1.3 * d_ufill / 2.0`）を計算する機能を実装する。 [4.3]

## 4. テストと検証
_Boundary: ConfigLoader.Tests_
_Depends: 2.1, 3.1_
- [ ] 4.1 ユニットテスト：必須項目欠落時のエラーハンドリングを検証する。 [1.2]
- [ ] 4.2 ユニットテスト：累積Z座標の計算結果が期待値と一致することを検証する。 [3.1]
- [ ] 4.3 統合テスト：`generate_test_config()` が `H2-main-original` の仕様と一致することを検証する。 [1.3]
