# Brief: gds-mapping

## Problem
GDSII形式の2D形状を、3Dモデルの特定の層のシリコンチップや熱源としてマッピングする必要がある。

## Current State
`SimpleGDS.jl` と `PolygonOps.jl` が使用されているが、実装が `modelA.jl` に直接記述されており再利用性が低い。

## Desired Outcome
GDSIIファイルから指定レイヤーのポリゴン情報を抽出し、BBox計算や点包含判定（Inside/Outside）をカプセル化したインターフェースを提供する。

## Approach
`SimpleGDS.jl` をラップするモジュールを作成し、ポリゴンごとのBBoxによる高速化判定を実装する。

## Scope
- **In**: GDSIIパース、BBox計算、ポリゴン包含判定。
- **Out**: Z方向の判定（geometry-logicが担当）。

## Downstream
- **Downstream**: geometry-logic, model-builder
