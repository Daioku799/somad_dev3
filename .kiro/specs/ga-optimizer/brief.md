# Brief: ga-optimizer

## Problem
3D-ICの熱設計において、制約条件を満たしつつ最高温度を最小化する最適なTSV配置（密度マップ）を見つけ出す必要がある。

## Current State
FVMソルバー（`H2-main-ext`）と、高速評価器としてのROM（`H2-rom`）が準備されている。

## Desired Outcome
遺伝的アルゴリズム（GA）を用いて、密度マップを最適化し、最高温度を最小化する設計案を提案する。また、上位候補についてはFVMで再検証し、物理的な妥当性を保証する。

## Approach
- **Genotype**: 密度マップベクトル `mu`。
- **Fitness**: ROMによる `Tmax` 予測値。
- **Constraints**: 総TSV本数上限、セル密度上限、配置禁止領域。
- **Validation**: 最終解およびエリート個体のFVM再検証。

## Scope
- **In**: GAの個体生成・交叉・突然変異、制約修正（密度正規化）、ROM評価ループ、外挿検知、有望解のFVM検証。
- **Out**: ROMの構築、FVM内部計算。

## Boundary Candidates
- GAコアロジック
- 密度制約修正エンジン（正規化・境界チェック）
- 信頼性マネージャ（ROM/FVMの使い分け、外挿判定）

## Out of Boundary
- LLMによる高度な分析（初期実装では対象外）。

## Upstream / Downstream
- **Upstream**: `rom-validator`, `config-loader`
- **Downstream**: 解析結果出力・レポート

## Existing Spec Touchpoints
- `config-loader`: 最適化パラメータの読み込み。

## Constraints
- **Core Requirement**: 最終解のFVM検証時は「密度マップ → 実TSV座標 → FVM」のフローを必ず通る。
- 再現性: 乱数シードの管理。
