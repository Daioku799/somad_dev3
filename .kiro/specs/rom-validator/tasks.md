# Implementation Plan: rom-validator

## 1. Foundation: モジュール基盤と型定義
- [x] 1.1 モジュール構造とデータ型の定義
  - `ValidationResult`, `ValidationSummary` 構造体の定義
  - `ROMValidator.jl` と `types.jl` の作成。必要なライブラリのインポート設定
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 1.2 (P) 評価用データ（スナップショット）の特定ロジック
  - `data/raw/` からモデル構築に使用されなかった検証用データを特定する `get_validation_samples` の実装
  - _Requirements: 2.1, 2.2_
  - _Boundary: Evaluator_

## 2. Core: 精度検証アルゴリズムの実装
- [x] 2.1 (P) 相対L2誤差およびTmax誤差の算出処理
  - 解析温度場と予測温度場の間の相対L2ノルム誤差を計算する `calculate_l2_error`
  - それぞれの最高温度の差を計算する `calculate_tmax_error` の実装
  - _Requirements: 1.1, 1.2_
  - _Boundary: Evaluator_

- [x] 2.2 (P) ホットスポット位置幾何誤差の算出処理
  - 1D平坦化インデックスから物理空間 3D 座標 $(x, y, z)$ への逆変換の実装
  - FVMとROMの最高温度点の間の直線（ユークリッド）物理距離を算出する `calculate_hotspot_error` の実装
  - _Requirements: 1.3_
  - _Boundary: Evaluator_

- [x] 2.3 精度合格判定ロジックの実装
  - 各ケースの評価および、平均Tmax誤差を閾値（既定 2.0 K）と比較して合否（`:validated`/`:unfit`）を決定するロジックの実装
  - _Requirements: 3.1, 3.2, 3.3_
  - _Boundary: Evaluator_
  - _Depends: 2.1, 2.2_

## 3. Reporting & Visualization: レポートとプロット生成
- [ ] 3.1 (P) テキストレポート（Markdown/JSON）出力機能
  - 各種統計（平均、最大）を集計し、`validation.md` および `validation.json` を出力する機能
  - _Requirements: 1.4, 4.1_
  - _Boundary: Reporter_

- [ ] 3.2 比較スライス断面図プロット機能の実装
  - `Plots.jl` を用いて、統一された座標位置（XY断面3面、YZ断面1面）を切り出すプロット生成処理
  - ヘッドレス環境でクラッシュしないための GR バックエンド非表示設定 (`ENV["GKSwstype"] = "100"`) の組み込み
  - 指定ディレクトリへの比較 PNG 画像の自動保存
  - _Requirements: 4.2, 4.3_
  - _Boundary: Reporter_

## 4. Integration: 統合パイプラインの構築
- [ ] 4.1 精度評価実行オーケストレータ API
  - スナップショットのデータ選定、予測実行、誤差計算、合否判定、レポート生成を一括で実行するハイレベル API `run_validation` の実装
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 3.1, 4.1, 4.2_
  - _Depends: 2.3, 3.2_

## 5. Validation: 統合テストの実施
- [ ] 5.1 統合テストによる E2E 動作検証
  - ダミースナップショットおよびROMモデルを用いた、検証データ選定・誤差計算・プロット保存・合格判定までの一連の自動テストの実行
  - ヘッドレス環境下（GUIのないテスト環境）で例外を吐かずにプロット生成が正常に完走することの検証
  - _Requirements: 4.2, 4.3_
