# Brief: component-generator

## Problem
TSV群やはんだバンプ群を個別に定義するのは手間がかかり、設定変更（ピッチや数）への対応が難しい。

## Current State
`generate_original_gds.jl` などで半手動的に生成されている。

## Desired Outcome
JSON設定に基づき、TSVの配列やはんだバンプの配置を自動計算し、幾何形状オブジェクトのリストとして生成する。

## Approach
- 行列配置ロジックを実装し、指定された領域内にコンポーネントを自動レイアウトする。
- 生成されたオブジェクトを `geometry-logic` で利用可能な形式で出力する。

## Scope
- **In**: TSV/バンプの配置計算、オブジェクト生成。
- **Out**: 個別の幾何判定（geometry-logicが担当）。

## Upstream / Downstream
- **Upstream**: config-loader
- **Downstream**: model-builder
