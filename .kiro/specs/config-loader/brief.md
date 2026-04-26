# Brief: config-loader

## Problem
モデルの寸法、層構造、物性値、TSV配置設定が複数のJSONに分散しており、ハードコードされた定数との整合性が取れなくなるリスクがある。

## Current State
`config.json` と `tsv_config.json` が存在するが、読み込みロジックが `modelA.jl` 内に混在している。

## Desired Outcome
JSONファイルを型安全に読み込み、プログラム全体で利用可能な定数オブジェクトを提供し、層厚の累積計算（zm0〜zm12）を自動化する。

## Approach
`JSON.jl` を使用し、設定値を保持する構造体を定義する。

## Scope
- **In**: `config.json`, `tsv_config.json` のパース、層境界Z座標の計算。
- **Out**: GDSIIデータの読み込み（gds-mappingが担当）。

## Upstream / Downstream
- **Downstream**: component-generator, model-builder
