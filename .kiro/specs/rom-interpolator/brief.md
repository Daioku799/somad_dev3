# Brief: rom-interpolator

## Problem
POD基底だけでは、未知の設計パラメータに対する温度場を予測できない。設計パラメータとモーダル係数の関係を学習する必要がある。

## Current State
`pod-engine` により、各スナップショットに対応するモーダル係数が算出されている（前提）。

## Desired Outcome
設計パラメータ（TSV情報）からモーダル係数への写像を補間し、任意のパラメータに対して温度場をミリ秒単位で予測できる。

## Approach
- 放射基底関数（RBF）を用いた多変数補間。
- 各モードの係数に対する独立した RBF モデルの構築。
- 入力パラメータの正規化とスケーリング。

## Scope
- **In**: RBFモデルの学習、ハイパーパラメータ調整（形状パラメータ等）、オンライン予測インターフェース。
- **Out**: 予測精度の詳細な評価（rom-validatorが担当）。

## Boundary Candidates
- モデル学習部（Training）
- 予測実行部（Predictor）
- パラメータ正規化部（Scaler）

## Out of Boundary
- 最適化アルゴリズム（GA）の実装。

## Upstream / Downstream
- **Upstream**: `pod-engine`
- **Downstream**: `rom-validator`, `GA-optimizer` (Phase 3)

## Existing Spec Touchpoints
- **Extends**: なし
- **Adjacent**: なし

## Constraints
- 予測速度（ミリ秒オーダー）。
- 補間精度の安定性。
