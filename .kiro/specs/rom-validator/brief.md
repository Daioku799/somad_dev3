# Brief: rom-validator

## Problem
構築されたROMが、学習データ以外（未知の密度マップ）に対してどの程度の予測精度を持つか不明である。

## Current State
`rom-interpolator` によりROMモデルが構築され、検証用スナップショットが `data/raw/` に存在する。

## Desired Outcome
検証用データを用いてROM予測結果とFVM解析結果を比較し、温度場全体の相対誤差、最高温度誤差（Tmax誤差）、ホットスポット位置のずれを定量的に評価する。

## Approach
- **誤差指標**: 平均相対誤差、最大絶対誤差、Tmax誤差。
- **合格判定**: 既定の閾値（Tmax平均誤差 2K以下等）に基づくROM採用判定。

## Scope
- **In**: 検証用データの読み込み、ROM予測の実行、FVM結果との比較計算、評価レポート生成。
- **Out**: スナップショット生成そのもの、ROMの学習。

## Boundary Candidates
- 誤差計算エンジン
- 評価レポート・可視化
- 精度合格判定基準の管理

## Out of Boundary
- 最適化中の検証（最適化フェーズでも使用するが、本SpecはROMそのものの品質保証に特化する）。

## Upstream / Downstream
- **Upstream**: `rom-interpolator`, `snapshot-generator`
- **Downstream**: `ga-optimizer` (合格済みROMのみ使用)

## Existing Spec Touchpoints
- なし

## Constraints
- `isapprox` を用いた物理量の比較。
- 相対誤差と絶対誤差の両面評価。
