# Brief: geometry-logic

## Problem
オリジナルの `H2-main-original` では幾何判定ロジックが `modelA.jl` にハードコードされており、拡張性が低い。また、GDSIIからの複雑なポリゴン判定と幾何プリミティブ（直方体、円柱）の判定を統合して扱う必要がある。

## Current State
`H2-main_TSV_Opt` では幾何判定が一部関数化されているが、GDSポリゴンとの連携が密結合である。

## Desired Outcome
任意の座標 (x, y, z) に対して、その地点がどのコンポーネント（シリコン、熱源、はんだ、TSV等）に属するかを返す、抽象化された幾何エンジンを構築する。

## Approach
- インターフェースを定義し、プリミティブ判定とGDSポリゴン判定（gds-mappingを使用）を統合する。
- 計算速度向上のため、層ごとに判定対象を絞り込むロジックを実装する。

## Scope
- **In**: 点の包含判定（Point-in-Shape）、プリミティブ形状の定義、GDS連携ロジック。
- **Out**: 具体的なグリッドへの充填（model-builderが担当）。

## Upstream / Downstream
- **Upstream**: gds-mapping
- **Downstream**: model-builder
