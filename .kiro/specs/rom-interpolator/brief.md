# Brief: rom-interpolator

## Problem
POD基底だけでは、未知の設計パラメータ（密度マップ）に対する温度場を予測できない。パラメータからPOD係数への写像が必要である。

## Current State
`pod-engine` により、学習データのパラメータ `mu` と、それに対応するPOD係数 `a` が算出されている。

## Desired Outcome
密度マップベクトル `mu` を入力とし、POD係数 `a` を出力する抽象化された補間モデル（デフォルト：RBF）を構築し、温度場を再構成できること。

## Approach
- **Interpolator Interface**: 抽象型 `AbstractInterpolator` により補間モデル（モーダル係数決定法）をオプショナルで変更可能にする。
- **RBF Network (Default)**: ガウスカーネルを用いたRBF補間をデフォルトの具象モデルとして提供。
- **Data Scaling**: 密度マップ `mu` の各セル値をデータスケーリングし、セル間の距離計算を安定させる。
- **Reliability Check (Box check)**: 各セルの最大最小範囲のボックス判定（案A）をデフォルトとしつつ、将来的に別の高度な判定手法に切り替え可能なように判定インターフェースを分離する。

## Scope
- **In**: RBF重みの学習、重みの保存・読込、未知 `mu` に対するPOD係数の予測、温度場の再構成機能、最高温度の抽出（`get_tmax`）、および信頼性判定（外挿検知）。
- **Out**: POD基底の抽出（`pod-engine`）、誤差評価（`rom-validator`）。

## Boundary Candidates
- RBF学習エンジン
- パラメータ・データスケーリング（Data Scaling）ユーティリティ
- ROMモデル統合（基底 + RBF重み）

## Out of Boundary
- 最適化アルゴリズム（`ga-optimizer` が担当）。

## Upstream / Downstream
- **Upstream**: `pod-engine`
- **Downstream**: `rom-validator`, `ga-optimizer`

## Existing Spec Touchpoints
- なし

## Constraints
- 入力次元: `Gx * Gy` (4x4 = 16等)。
- データの不変性: 学習済み重みの不変データ管理。
