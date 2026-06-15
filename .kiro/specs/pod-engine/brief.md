# Brief: pod-engine

## Problem
FVMソルバーによる温度場解析（スナップショット）は高次元データであり、そのままではROM構築やGA最適化の評価器として使用するには計算負荷が高すぎる。

## Current State
`H2-rom/src/SnapshotGenerator` により、パラメータを変化させた複数のFVMスナップショット（.jld2）が `data/raw/` に蓄積されている。

## Desired Outcome
スナップショット行列からPOD（固有直交分解）を用いて、温度場の支配的な空間基底を抽出し、低次元の近似空間を構築する。

## Approach
- **SVD (特異値分解)**: スナップショット行列に対してSVDを実行し、特異値と左特異ベクトルを取得する。
- **RIC (累積寄与率)**: 累積寄与率（既定0.999以上）に基づいて、保持するPOD基底数 `r` を決定する。

## Scope
- **In**: スナップショット行列の構築、SVDの実行、POD基底の保存、各スナップショットのPOD係数（射影）計算。
- **Out**: RBF補間（`rom-interpolator` が担当）、物理ソルバーの実行。

## Boundary Candidates
- スナップショット読み込みと行列化
- SVD演算とRIC判定
- 基底データ（POD Modes）の永続化

## Out of Boundary
- 温度場の再構成（予測）ロジックそのもの（Interpolatorと共通のデータ構造を使用するが、抽出に専念する）。

## Upstream / Downstream
- **Upstream**: `snapshot-generator` (JLD2データ)
- **Downstream**: `rom-interpolator` (基底データを使用)

## Existing Spec Touchpoints
- なし

## Constraints
- Julia `LinearAlgebra.jl` の使用。
- `JLD2.jl` による基底の保存。
