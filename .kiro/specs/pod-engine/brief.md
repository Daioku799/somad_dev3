# Brief: pod-engine

## Problem
高次元な温度場データ（格子点数 240x240x31）をそのまま扱うと、最適化計算における予測コストが極めて高い。

## Current State
`data/raw/` にスナップショット群が蓄積されている（前提）。

## Desired Outcome
スナップショット行列に対してSVDを適用し、支配的な空間モード（POD基底）と固有値を抽出・保存できる。

## Approach
- スナップショットのプリプロセス（平均場の除去）。
- SVDによる特異値分解。
- 累積エネルギー寄与率（RIC）に基づいた最適な基底数の決定。

## Scope
- **In**: データロード、SVD実行、基底抽出、RIC計算、モデルエクスポート。
- **Out**: パラメータ補間（rom-interpolatorが担当）。

## Boundary Candidates
- データ整形部（Preprocessor）
- 特異値分解実行部（SVD Solver）
- モード管理部（Basis Manager）

## Out of Boundary
- ROMのオンライン予測。

## Upstream / Downstream
- **Upstream**: `snapshot-generator`
- **Downstream**: `rom-interpolator`

## Existing Spec Touchpoints
- **Extends**: なし
- **Adjacent**: なし

## Constraints
- メモリ使用量の最適化（大規模行列の扱い）。
- 数値的安定性の確保。
