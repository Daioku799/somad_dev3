# Brief: validation-plot

## Problem
構築されたモデルが意図通りか（TSVが正しい層を貫通しているか、バンプの位置がずれていないか）を視覚的に確認する必要がある。

## Current State
`plot_materials.jl` などで断面図を作成しているが、自動化されていない。

## Desired Outcome
構築されたIDグリッド（model-builderの出力）を読み込み、指定されたXY断面やYZ断面のプロットを自動生成する。

## Approach
`Plots.jl` や `PyPlot.jl` を使用し、IDに基づいた色分け地図を作成する。

## Scope
- **In**: IDグリッドの断面描画、画像保存。
- **Out**: 3Dレンダリング、解析結果（温度等）の描画。

## Upstream / Downstream
- **Upstream**: model-builder
