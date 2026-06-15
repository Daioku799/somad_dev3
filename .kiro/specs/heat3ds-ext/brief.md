# Brief: heat3ds-ext

## Problem
オリジナルのFVMソルバー（`heat3ds.jl`）は、計算結果をテキストログやCSV、画像として出力するが、ROM構築用のバイナリ形式（JLD2）での温度場保存に対応していない。

## Current State
`H2-main-ext/src/heat3ds.jl` にソルバーのメインループが存在し、計算終了後に `plotter.jl` 等を呼び出している。

## Desired Outcome
計算終了後、収束した温度場（3次元配列 $\theta$）を JLD2 形式でファイル保存する機能を `heat3ds.jl` またはその周辺に追加する。

## Approach
- `JLD2.jl` を使用し、配列データをシリアライズして保存する。
- 保存ファイル名は、`snapshot-generator` から指定可能にする。

## Scope
- **In**: 温度場 $\theta$ の JLD2 保存ロジック、保存パスの指定機能。
- **Out**: 温度場の可視化（`plotter.jl`が担当）。

## Upstream / Downstream
- **Upstream**: `snapshot-generator` (保存指示を出す)
- **Downstream**: `snapshot-generator` (保存されたファイルを利用)
