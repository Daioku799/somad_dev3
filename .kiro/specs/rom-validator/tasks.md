# Implementation Plan - rom-validator

## Task Progression Summary
1. Foundation: データ構造とモジュール基盤の構築 (Tasks 1.1 - 1.2)
2. Core Logic: 誤差評価エンジンの実装 (Tasks 2.1 - 2.3)
3. Reporting: 評価レポートと可視化の生成 (Tasks 3.1 - 3.2)
4. Validation: 統合テストと最終検証 (Tasks 4.1 - 4.2)

## Implementation Tasks

### 1. Foundation: データ構造とモジュール基盤の構築
- [ ] 1.1 評価結果および評価コンテキストを保持するデータ構造の定義
  - `H2-rom/src/ROMValidator/types.jl` に `ValidationResult`, `ValidationSummary`, および物理情報を保持する `EvaluationContext` 構造体を実装する。
  - 各スナップショットの相対L2誤差、Tmax誤差、ホットスポット位置誤差（物理距離）を保持できるフィールドを持たせる。
  - `_Requirements: 1.1, 1.2, 1.3, 1.4_`
- [ ] 1.2 モジュールエントリポイントの作成
  - `H2-rom/src/ROMValidator/ROMValidator.jl` を作成し、主要な型と評価実行関数をエクスポートする。
  - `using ROMValidator` がエラーなく実行できる。
  - `_Requirements: 1.4_`

### 2. Core Logic: 誤差評価エンジンの実装
- [ ] 2.1 (P) 検証用サンプルの自動特定ロジック
  - `data/raw/` 内の全スナップショットと `pod_model.jld2` のメタデータを比較し、学習に使用されていないファイルリストを抽出する。
  - 重複や漏れがないことを検証サンプルリストの数で確認できる。
  - `_Requirements: 2.1_`
  - _Boundary: Evaluator_
- [ ] 2.2 (P) 各種誤差計算関数の実装
  - 温度場全体の相対L2誤差、Tmax絶対誤差、ホットスポット位置のユークリッド距離を計算する関数を実装する。
  - `PODModel` または共有設定から `lx, ly, lz` およびグリッド情報を取得し、評価コンテキストを構築する。
  - ホットスポット位置は `argmax` で得たインデックスを、この評価コンテキスト（物理座標情報）に基づき物理座標に変換して計算する。
  - `_Requirements: 1.1, 1.2, 1.3_`
  - _Boundary: Evaluator_
- [ ] 2.3 評価実行オーケストレーターの実装
  - 特定された検証サンプルを順次ロードし、ROM予測（`predict_coeffs` + `reconstruct_field`）を実行してFVM結果と比較するループを実装する。
  - Tmax平均誤差が閾値（2.0 K）以下か判定し、ROM全体のステータス（`:validated` / `:unfit`）を決定する。
  - `_Requirements: 2.2, 3.1, 3.2, 3.3_`
  - _Depends: 2.1, 2.2_

### 3. Reporting: 評価レポートと可視化の生成
- [ ] 3.1 (P) 統計サマリーとレポート出力機能
  - 全検証結果の平均値、最大値、標準偏差を集計し、`data/reports/validation_report.md` および `.json` を生成する。
  - 生成されたファイルに全ての誤差指標と最終判定結果が含まれている。
  - `_Requirements: 1.4, 4.1_`
  - _Boundary: Reporter_
- [ ] 3.2 (P) ROM vs FVM 比較プロットの生成
  - `Plots.jl` を用い、特定の検証ケースについてROM予測、FVM解析結果、およびそれらの誤差マップ（温度差の分布）を表示する断面プロットを生成する。
  - 最も誤差が大きいケース（Worst Case）を自動選択して保存する。
  - `_Requirements: 4.2_`
  - _Boundary: Reporter_

### 4. Validation: 統合テストと最終検証
- [ ] 4.1* メトリクス計算のユニットテスト
  - 既知のホットスポット位置のずれや一定の温度差を持つダミーデータに対し、誤差計算関数が正しい値を返すことを確認する。
  - `_Requirements: 1.1, 1.2, 1.3_`
- [ ] 4.2 統合エンドツーエンドテスト
  - 少数のダミー検証サンプルとモデルを用い、`run_validation` からレポート生成までの一連のフローが正常に完了することを確認する。
  - `_Requirements: 1.4, 3.1, 4.1_`
