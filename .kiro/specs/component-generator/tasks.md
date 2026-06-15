# Implementation Plan: component-generator

## 1. Foundation: Types and Interface Setup
- [ ] 1.1 `ComponentGenerator` の内部データ構造の定義
  - 密度セルの幾何学的情報（境界、中心座標）を保持する `DensityCell` 構造体を定義する。
  - バリデーション結果（エラー種別、詳細）を表現する型を定義する。
  - `Types.jl` において、`GeometryLogic` と互換性のあるプリミティブ型を整理する。
  - _Requirements: 5.2_
  - _Boundary: Types.jl_

- [ ] 1.2 メイン API 構造の構築
  - `src/ComponentGenerator/ComponentGenerator.jl` において `generate_all_components` の基本シグネチャを実装する。
  - 各モジュール（Layout, Validator）へのディスパッチ枠組みを作成する。
  - _Requirements: 5.1_
  - _Boundary: ComponentGenerator.jl_

## 2. Core: 配置ロジックの実装
- [ ] 2.1 (P) 密度マップ（mu）からの座標展開ロジックの実装
  - 密度ベクトル `mu` を $G_x \times G_y$ のセルに対応付け、各セル内での最大本数 $n_{max,ij}$ を算出する機能を実装する。
  - 算出された本数 $n_{ij}$ に基づき、セル内中央寄せの格子配置を行うロジックを実装する。
  - セル境界付近でのピッチ維持のためのガード（オフセット）を適用する。
  - _Requirements: 1.1, 1.2, 1.3, 2.1_
  - _Boundary: Layout.jl_

- [ ] 2.2 (P) はんだバンプの自動生成と垂直アライメント
  - 各 TSV 座標 (x, y) に同期したバンプオブジェクトの生成ロジックを実装する。
  - TSV 半径とアンダーフィル厚さから安全なバンプ半径 $R$ を算出する公式を実装する。
  - シリコン層とアンダーフィル層を跨ぐ垂直方向の座標一致を保証する。
  - _Requirements: 2.2, 3.1, 3.2_
  - _Boundary: ComponentGenerator.jl_

- [ ] 2.3 (P) 物理制約バリデータの実装
  - 全コンポーネントがチップ境界（lx, ly）内に収まっているかを判定する境界チェック機能を実装する。
  - コンポーネント間の中心距離が最小ピッチ $p_{min}$ を下回っていないかを判定する干渉チェック機能を実装する。
  - _Requirements: 4.1, 4.2, 4.3_
  - _Boundary: Validator.jl_

## 3. Integration: 統合とメタデータ管理
- [ ] 3.1 コンポーネント生成フローの統合
  - レイアウト生成、バリデーション、オブジェクト構築を一連のフローとして `generate_all_components` 内で結合する。
  - バリデーションエラー発生時の早期リターンおよびエラーメッセージ出力を実装する。
  - _Requirements: 5.1_
  - _Boundary: ComponentGenerator.jl_
  - _Depends: 2.1, 2.3_

- [ ] 3.2 密度マップと物理座標のメタデータ追跡
  - 展開された実座標と元の密度ベクトル `mu` の対応関係を追跡し、メタデータとして保持・出力する機能を実装する。
  - _Requirements: 5.2_
  - _Boundary: Types.jl, ComponentGenerator.jl_

## 4. Validation: ユニットテストと検証
- [ ] 4.1 密度デコードの正確性検証
  - 密度 0.0, 0.5, 1.0 の各ケースで、生成される本数と配置が物理制約（ピッチ）を満たしているかを確認する。
  - 異常な密度値や境界条件に対するエラーハンドリングをテストする。
  - _Requirements: 1.1, 1.3, 4.1, 4.2_

- [ ] 4.2* 統合検証テスト
  - `config-loader` から取得した実際の密度マップ `mu` を用い、全チップ層で TSV が正しく貫通していることを断面判定で確認する。
  - _Requirements: 2.2, 5.1_
