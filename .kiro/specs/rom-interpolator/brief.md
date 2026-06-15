# Brief: rom-interpolator

## Problem
POD基底だけでは、未知の設計パラメータ（密度マップ）に対する温度場を予測できない。パラメータからPOD係数への写像が必要である。

## Current State
`pod-engine` により、学習データのパラメータ `mu` と、それに対応するPOD係数 `a` が算出されている。

## Desired Outcome
密度マップベクトル `mu` を入力とし、POD係数 `a` を出力する非線形補間モデル（RBF: 放射基底関数）を構築し、温度場を再構成できること。

## Approach
- **RBF Network**: ガウスカーネル等を用いたRBF補間を実装。
- **Data Scaling**: 密度マップ `mu` の各セル値をデータスケーリング（Data Scaling）し、セル間の距離計算を安定させる。
- **Reliability Check**: 学習データの範囲外（外挿）を検知し、予測の信頼性を評価する。

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
