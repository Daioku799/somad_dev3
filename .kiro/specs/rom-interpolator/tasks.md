# Implementation Plan: rom-interpolator

## 1. Foundation: データ構造と正規化
- [ ] 1.1 `ROMInterpolator` モジュールの基本構造と型定義
  - `RBFModel`, `NormalizationParams`, `RBFWeights` 等の不変構造体の定義
  - `LinearAlgebra`, `JLD2` のインポートと基本モジュール構成の構築
  - 実行可能な `struct` 定義が `src/ROMInterpolator/types.jl` に存在すること
  - _Requirements: 1.1, 4.1_

- [ ] 1.2 (P) 密度マップの正規化ロジックの実装
  - 学習データから最小値・最大値を抽出する `fit_normalizer` の実装
  - 入力ベクトルを指定範囲（例: [0, 1]）にスケーリングする `normalize` の実装
  - 予測時に学習時のパラメータを再利用できること
  - 任意のベクトルが正しくスケーリングされ、逆変換または一貫性が保たれていることがテストで確認できること
  - _Requirements: 2.1, 2.2_
  - _Boundary: Normalizer_

## 2. Core: RBF マッピングの実装
- [ ] 2.1 (P) RBF カーネル計算の実装
  - ガウスカーネル等の距離ベース関数の実装
  - マルチ出力（全PODモード一括）に対応したカーネル行列の生成ロジック
  - 任意の距離行列に対して正しいカーネル値が返されること
  - _Requirements: 1.1_
  - _Boundary: RBFEngine_

- [ ] 2.2 RBF 重み算出（学習）ロジックの実装
  - 正規化された密度マップとPOD係数行列から、最小二乗法（`\` 演算子）を用いた重み行列 $W$ の算出
  - 過学習を抑制するための正則化項（Ridge）の導入
  - サンプル数不足や次元不一致に対するバリデーションとエラー表示の実装
  - 学習データを与えたときに適切な重み行列が生成され、エラーなく完了すること
  - _Requirements: 1.1, 1.3_
  - _Boundary: RBFEngine_
  - _Depends: 1.2_

- [ ] 2.3 (P) POD係数の予測ロジック
  - 学習済み重みと新しい入力 $\mu$ から、RBF補間を用いてPOD係数ベクトル $a$ を算出する機能
  - 入力ベクトルに対して $r$ 次元の係数ベクトルが即座に返されること
  - _Requirements: 3.1_
  - _Boundary: RBFEngine_

- [ ] 2.4 (P) 外挿検知（信頼性判定）API の実装
  - 入力 $\mu$ が学習データの範囲（`parameter_bounds`）内にあるか判定する `is_reliable` の実装
  - 範囲外の入力に対して警告または `false` を返す機能の確認
  - ユニットテストによる境界条件の検証
  - _Requirements: 5.1_
  - _Boundary: ReliabilityGuard_

## 3. Core: 温度場再構成と形状変換
- [ ] 3.1 温度場ベクトルの再構成ロジック
  - 平均場 $\bar{\theta}$、POD基底 $\Phi$、および予測係数 $a$ の線形結合（ $\theta = \bar{\theta} + \Phi a$ ）の実装
  - 計算結果が元のスナップショットと同じ次元のベクトルとして生成されること
  - _Requirements: 3.2_
  - _Boundary: Reconstructor_

- [ ] 3.2 (P) 3Dグリッド形状への変換
  - 1次元ベクトル形式の温度場を、元の $Nx \times Ny \times Nz$ グリッド形状に変換する機能
  - 配列の次元組み換え（reshape）が正しく行われ、物理的な座標系と整合していること
  - _Requirements: 3.3_
  - _Boundary: Reconstructor_

## 4. Integration & Persistence: パイプラインと永続化
- [ ] 4.1 モデルの保存・読み込み機能
  - `JLD2` を用いた `RBFModel` のシリアライズとデシリアライズ
  - 重み、中心点、正規化パラメータ、カーネル設定の一括保存
  - `data/models/rom_model.jld2` が正しく生成・復元されること
  - _Requirements: 4.1, 4.2_

- [ ] 4.2 学習・予測のハイレベル API の統合
  - 正規化、RBF学習、保存を順次実行する `train_rom` 関数の実装
  - 読み込まれたモデルを用いた予測・再構成を一括で行う API の提供
  - サンプルデータを用いて、一連のパイプラインが正常に完結すること
  - _Requirements: 1.1, 1.2, 3.1, 3.2_

## 5. Validation: 統合テスト
- [ ] 5.1 `pod-engine` 出力を用いた統合検証
  - 実際の `pod_model.jld2` と密度マップデータを用いた学習の実行
  - 未知のパラメータに対する再構成温度場の生成と、物理的な妥当性の確認（極端な値の不在等）
  - 全工程がエラーなく完了し、モデルファイルが期待通りに更新されること
  - _Requirements: 1.1, 3.1, 3.2_
