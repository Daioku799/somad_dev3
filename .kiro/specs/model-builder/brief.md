# Brief: model-builder

## Problem
高解像度な3次元IDグリッド（240x240x31等）を効率的に充填し、熱解析ソルバーに渡せる形式で保存する必要がある。

## Current State
`modelA.jl` でループ処理により ID グリッドを充填しているが、ロジックが肥大化している。

## Desired Outcome
`geometry-logic` と `component-generator` を利用して、指定された解像度の3次元IDグリッドを構築し、境界条件や物性値マップと統合する。

## Approach
- Z軸、Y軸、X軸の順でループし、各点での材料IDを判定・記録する。
- 結果をJLD2またはバイナリ形式で保存する。

## Scope
- **In**: 3Dグリッドの充填、境界条件の設定、データの永続化。
- **Out**: 幾何判定の詳細ロジック、プロット表示。

## Upstream / Downstream
- **Upstream**: config-loader, geometry-logic, component-generator
- **Downstream**: validation-plot
