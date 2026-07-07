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
- [x] 3.1 (P) テキストレポート（Markdown/JSON）出力機能
  - 各種統計（平均、最大）を集計し、`validation.md` および `validation.json` を出力する機能
  - _Requirements: 1.4, 4.1_
  - _Boundary: Reporter_

- [x] 3.2 比較スライス断面図プロット機能の実装
  - `Plots.jl` を用いて、統一された座標位置（XY断面3面、YZ断面1面）を切り出すプロット生成処理
  - ヘッドレス環境でクラッシュしないための GR バックエンド非表示設定 (`ENV["GKSwstype"] = "100"`) の組み込み
  - 指定ディレクトリへの比較 PNG 画像 of 自動保存
  - _Requirements: 4.2, 4.3_
  - _Boundary: Reporter_

## 4. Integration: 統合パイプラインの構築
- [x] 4.1 精度評価実行オーケストレータ API
  - スナップショットのデータ選定、予測実行、誤差計算、合否判定、レポート生成を一括で実行するハイレベル API `run_validation` の実装
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 3.1, 4.1, 4.2_
  - _Depends: 2.3, 3.2_

## 5. Validation: 統合テストの実施
- [x] 5.1 統合テストによる E2E 動作検証
  - ダミースナップショットおよびROMモデルを用いた、検証データ選定・誤差計算・プロット保存・合格判定までの一連の自動テストの実行
  - ヘッドレス環境下（GUIのないテスト環境）で例外を吐かずにプロット生成が正常に完走することの検証
  - _Requirements: 4.2, 4.3_

## 6. Visualization Optimization: 可視化機能の改善とオプション制御
- [x] 6.1 (P) スナップショットおよびROM予測における統合横並びプロットの実装
  - スナップショット可視化：密度マップ(4x4)、IDマップ(物理配置)、温度場の3枚を横並びにした3連プロット画像（`*_snapshot_xy.png`）を生成する処理の実装。
  - ROM予測可視化：密度マップ、FVM結果、ROM結果、温度差プロット（FVM - ROMの符号付き差分、`:balance`カラーマップ対称表示）を横並びにした4連プロット画像（`rom_fvm_comparison_xy.png`）を生成する処理の実装。
  - オプション引数 `save_individuals` により、統合プロットに加えて個別のプロット画像も保存するか否かを切り替える制御ロジックの追加。
  - 統合プロット画像が正しく1つのファイルとして生成され、個別保存オプション無効時には余分な個別画像が保存されないこと。
  - _Requirements: 4.3, 4.4, 4.5, 4.6_
  - _Boundary: ValidationPlot_

- [x] 6.2 (P) 相対温度場（正規化）プロットオプションの実装
  - FVMの各ケースの最大温度・最小温度を用いて、FVMとROMの温度場を [0.0, 1.0] にスケーリング正規化する処理の実装。
  - 相対温度場表示を切り替えるオプション引数 `normalize` をプロット処理に追加。
  - 相対温度場表示オプション有効時、温度分布が [0.0, 1.0] の相対値でヒートマップ描画されること。
  - _Requirements: 4.7_
  - _Boundary: ValidationPlot_

- [x] 6.3 レポーターモジュールにおけるプロット生成処理のリファクタリング
  - `generate_comparison_plots` の中から不要な複数 Z / YZ 断面の描画処理を削除し、代表となる中央 Z 断面（z = 0.35 mm）に対して `plot_rom_comparison` を1回のみ呼び出すように修正。
  - `generate_report` で出力する Markdown レポート内の参照画像リンクを、4連統合プロット画像のみを参照するように変更。
  - 検証実行後、指定ディレクトリに中央 Z 断面の4連比較画像1枚のみが出力され、Markdownレポートからその画像へのリンクが正常に張られていること。
  - _Requirements: 4.2_
  - _Depends: 6.1, 6.2_
  - _Boundary: Reporter_

## 7. Metrics & Verification: 性能指標プロファイルと自己再現精度検証
- [ ] 7.1 (P) データセット容量およびFVM実行時間の測定ロジックの実装
  - `snapshot_dir` 配下の全 `.jld2` スナップショットファイルの合計ファイルサイズ（バイト単位）を算出する処理の実装。
  - `data/manifest.json` から成功ケースの `runtime` を合計・平均算出する処理の実装。
  - 測定された総スナップショットファイルサイズおよびFVMの総時間・平均秒数が正しく内部的に取得できること。
  - _Requirements: 5.1, 5.2_
  - _Boundary: Evaluator_

- [ ] 7.2 (P) 学習データを用いた自己再現精度の検証ロジックの実装
  - `trained_snapshot_ids` のスナップショット群に対してROM予測を実行し、自己再現の相対L2誤差およびTmax絶対誤差を算出する処理。
  - 自己再現誤差の最大 Tmax 誤差が 0.5 K を超過する場合に警告ステータス（`:warning`）を決定する判定ロジックの実装。
  - 学習データに対する誤差（自己再現誤差）が正しく計算され、規定値を超えた場合に警告フラグが立つこと。
  - _Requirements: 6.1, 6.3_
  - _Boundary: Evaluator_

- [ ] 7.3 (P) 検証処理時の例外・エラーハンドリングの実装
  - 検証ケースのファイル破損やグリッドサイズ不整合時に発生する例外を `try-catch` でトラップし、警告ログを出力しつつ安全にスキップして次のケースへ進む制御の実装。
  - 破損したダミーデータ混入時でも処理全体が途中でクラッシュせず、正常なケースのみを検証し終えてレポート出力に到達すること。
  - _Requirements: 2.3_
  - _Boundary: Evaluator_

- [ ] 7.4 性能指標・自己再現統計のレポート出力と API 拡張
  - `run_validation` の引数に `rom_build_time` や可視化オプションを追加。時間計測（ROM予測クエリ時間、総評価時間など）の組み込み。
  - `types.jl` の `ValidationSummary` 構造体のフィールド拡張（`performance_metrics`, `self_reproduction_metrics` 追加）。
  - `generate_report` で出力する Markdown / JSON レポートに、測定された時間・サイズ・自己再現誤差・警告ステータスを含めて保存する処理。
  - 出力される `validation.md` および `validation.json` 内に、各種性能メトリクスと自己再現メトリクスの表やデータが正しく記録されていること。
  - _Requirements: 1.4, 4.1, 5.3, 6.2_
  - _Depends: 7.1, 7.2, 7.3_
  - _Boundary: ROMValidator_

## 8. Validation: 機能検証とテスト実行
- [ ] 8.1 (P) 単体テストの拡張による機能検証
  - 正規化プロットスケーリング、性能メトリクス集計、自己再現誤差判定、例外処理スキップの各機能の単体テストを `test/` 内に追加し、実行する。
  - `julia --project=. test/run_tests.jl` にて、追加された全単体テストが正常に PASS すること。
  - _Requirements: 2.3, 4.7, 5.1, 6.3_

- [ ] 8.2 統合E2E検証の実行と生成画像の確認
  - `evaluate_rom_workflow.jl` を新 API およびオプション対応で実行し、プロット画像のレイアウト変更（3連・4連）、個別画像のクリーンアップ、自己再現や時間プロファイルのレポート出力が正常に行われていることを動作確認する。
  - `plots/validation/` に統合画像のみ（個別画像なし）が出力され、Markdown レポートの内容と同期していること。
  - _Requirements: 4.1, 4.2, 4.3, 4.5, 5.3, 6.2_
  - _Depends: 6.3, 7.4_
