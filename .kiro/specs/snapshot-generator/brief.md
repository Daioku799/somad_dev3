# Brief: snapshot-generator

## Problem
ROM構築には大量の教師データ（スナップショット）が必要だが、手動でパラメータを変更してソルバーを実行するのは非効率であり、ミスが発生しやすい。

## Current State
`H2-main-ext` により、JSON設定を介して単一のシミュレーションを実行できる状態にある。しかし、一括実行や結果の自動保存機能はない。

## Desired Outcome
数百〜数千パターンのパラメータセットを自動生成し、FVMソルバーを連続実行して、各ケースの結果（温度場）とパラメータを `data/raw/` に蓄積できる。

## Approach
- ラテン超格子サンプリング（LHS）によるパラメータ空間の網羅。
- Juliaの並列処理（またはジョブ管理）によるソルバーの並列実行。
- 異常終了した計算を検知し、ログを残してスキップするエラーハンドリング。

## Scope
- **In**: パラメータサンプリング、FVM一括実行、JLD2形式での結果保存。
- **Out**: ROM自体の構築（pod-engineが担当）。

## Boundary Candidates
- パラメータサンプリング部（Sampling）
- ソルバー実行・監視部（Orchestrator）
- データ永続化部（Exporter）

## Out of Boundary
- ソルバー本体（heat3ds.jl）のロジック変更。

## Upstream / Downstream
- **Upstream**: `model-builder` (H2-main-ext)
- **Downstream**: `pod-engine`

## Existing Spec Touchpoints
- **Extends**: なし
- **Adjacent**: `config-loader` (JSONフォーマットの共有)

## Constraints
- ソルバーの最大実行時間制限（タイムアウト管理）。
- ディスク容量への配慮（不要な中間ファイルの削除）。
