# Implementation Plan: rom-interpolator

## 1. Foundation: データ構造と正規化
- [x] 1.1 `ROMInterpolator` モジュールの基本構造と型定義
  - 抽象型 `AbstractInterpolator` および具象型 `RBFInterpolator`, `ScalingParams` 等の定義
  - `LinearAlgebra`, `JLD2` のインポートと基本モジュール構成の構築
  - 実行可能な `struct` 定義が `src/ROMInterpolator/types.jl` に存在すること
  - _Requirements: 1.1, 1.3, 4.1_

- [ ] 1.2 (P) 密度マップの正規化 (Data Scaling) ロジックの実装
  - 学習データから最小値・最大値を抽出する `fit_scaler` の実装
  - 入力ベクトルを指定範囲（例: [0, 1]）にスケーリングする `scale_data` の実装
  - 予測時に学習時のパラメータを再利用できること
  - 任意のベクトルが正しくスケーリングされ、一貫性が保たれていることがテストで確認できること
  - _Requirements: 2.1, 2.2_
  - _Boundary: DataScaler_

## 2. Core: RBF マッピングの実装
- [ ] 2.1 (P) RBF カーネル計算の実装
  - ガウスカーネル等の距離ベース関数の実装
  - マルチ出力（全PODモード一括）に対応したカーネル行列の生成ロジック
  - 任意の距離行列に対して正しいカーネル値が返されること
  - _Requirements: 1.3_
  - _Boundary: Interpolator_

- [ ] 2.2 RBF 重み算出（学習）および予測 API の実装
  - 抽象 API `fit!(interpolator::AbstractInterpolator, X::Matrix{Float64}, Y::Matrix{Float64})` および `predict(interpolator::AbstractInterpolator, x::Vector{Float64})` の定義
  - `RBFInterpolator` における最小二乗法を用いた重み行列の算出と予測処理
  - サンプル数不足や次元不一致に対するバリデーションとエラー表示の実装
  - 学習データを与えたときに適切な重みが生成され、予測値が正常に計算されること
  - _Requirements: 1.2, 1.3, 1.4, 3.1_
  - _Boundary: Interpolator_
  - _Depends: 1.2_

- [ ] 2.3 (P) 外挿検知（信頼性判定）API の実装
  - 入力 `mu` が学習データの範囲内にあるか判定する `is_reliable(interpolator::AbstractInterpolator, mu::Vector{Float64})` の実装
  - `RBFInterpolator` に対して、デフォルトで各セルごとの最小値・最大値範囲内であるか（ボックス判定）を確認する処理の実装
  - 判定ロジックが差し替え可能（拡張性）であることの確認
  - ユニットテストによる境界条件の検証
  - _Requirements: 5.1, 5.2, 5.3_
  - _Boundary: ReliabilityGuard_

## 3. Core: 温度場再構成と形状変換
- [ ] 3.1 温度場ベクトルの再構成ロジック
  - 平均場 $\bar{\theta}$、POD基底 $\Phi$、および予測された係数 $a$ の線形結合（ $\theta = \bar{\theta} + \Phi a$ ）の実装
  - 計算結果が元のスナップショットと同じ次元のベクトルとして生成されること
  - _Requirements: 3.2_
  - _Boundary: Reconstructor_

- [ ] 3.2 (P) 3Dグリッド形状への変換と最高温度抽出
  - 1次元ベクトル形式の温度場を、元の $Nx \times Ny \times Nz$ グリッド形状に変換する機能
  - 再構成温度場から最高温度を抽出する `get_tmax(theta)` の実装
  - _Requirements: 3.3, 3.4_
  - _Boundary: Reconstructor_

## 4. Integration & Persistence: パイプラインと永続化
- [ ] 4.1 モデルの保存・読み込み機能
  - `JLD2` を用いた `AbstractInterpolator`（`RBFInterpolator`）オブジェクト全体のシリアライズとデシリアライズ
  - `save_rom_model(filepath, model)` および `load_rom_model(filepath)` の実装
  - モデルが正しくファイルに保存・復元されること
  - _Requirements: 4.1, 4.2_

- [ ] 4.2 ハイレベル API の統合
  - スケーリング、学習、保存を順次実行する `train_rom` 関数の実装
  - 読み込まれたモデルを用いた予測・再構成を一括で行う API の提供
  - サンプルデータを用いて、一連のパイプラインが正常に完結すること
  - _Requirements: 1.1, 1.2, 3.1, 3.2_

## 5. Validation: 統合テスト
- [ ] 5.1 `pod-engine` 出力を用いた統合検証
  - 実際の `pod_model.jld2` と密度マップデータを用いた学習の実行
  - 未知のパラメータに対する再構成温度場の生成と、物理的な妥当性の確認（極端な値の不在等）
  - 全工程がエラーなく完了し、モデルファイルが期待通りに更新されること
  - _Requirements: 1.1, 3.1, 3.2_
