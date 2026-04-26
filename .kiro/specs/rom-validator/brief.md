# Brief: rom-validator

## Problem
構築されたROMが、最適化に使用できるほど十分な精度を持っているか不明である。

## Current State
`rom-interpolator` により、予測モデルが構築されている（前提）。

## Desired Outcome
学習に使用していない未知のパラメータ（テストデータ）に対し、ROM予測値とFVM解析値を比較し、誤差（L2ノルム、最大温度誤差、平均絶対誤差）を報告できる。

## Approach
- 交差検証（Cross-validation）または独立したテストセットによる評価。
- 誤差分布のヒストグラム作成。
- 特定パラメータにおけるROM予測断面図とFVM断面図の視覚的比較。

## Scope
- **In**: 誤差計算ロジック、検証用データ管理、レポート生成、比較プロット。
- **Out**: ROMの再学習（rom-interpolatorが担当）。

## Boundary Candidates
- 精度評価部（Evaluator）
- レポート生成部（Reporter）
- 視覚的比較部（Visualizer）

## Out of Boundary
- 学習データの生成。

## Upstream / Downstream
- **Upstream**: `rom-interpolator`
- **Downstream**: なし（ROM構築の完了判定）

## Existing Spec Touchpoints
- **Extends**: なし
- **Adjacent**: `validation-plot` (プロットロジックの共有)

## Constraints
- 物理的に重要な指標（最大温度の精度）を優先した評価。
- 再現性の確保。
