# Requirements: model-builder

## 1. モデル構築の統合と再現性
- 1.1 The Model Builder shall orchestrate `ConfigLoader`, `GdsMapping`, `ComponentGenerator`, and `GeometryLogic` to construct the full 3D simulation domain.
- 1.2 **[オリジナルの再現]** The Model Builder shall produce 3D ID maps that are bit-for-bit compatible (or within numeric tolerance) with `H2-main-original` when provided with identical input parameters.
- 1.3 **[上書き禁止ルールの継承]** When filling the 3D ID map, the Model Builder shall process components in the specified order (PowerGrid > TSV > Silicon > Solder > Resin) and only fill cells that have an ID of zero.

## 2. 格子座標系の生成
- 2.1 **[非一様格子の構築]** The Model Builder shall generate a non-uniform Z-coordinate vector based on the layer grading parameters provided by `ConfigLoader`.
- 2.2 **[境界セルの包含]** The Model Builder shall include ghost/boundary cells (typically +2 per dimension) in the generated 3D maps to satisfy the requirements of the heat solver.

## 3. 3D ID および物性マップの生成
- 3.1 When generating the ID map, the Model Builder shall use `GeometryLogic` to determine the material ID for each cell, including those defined by complex GDSII shapes.
- 3.2 The Model Builder shall apply BBox-based range optimization for each component to minimize the number of calls to the geometry engine.
- 3.3 The Model Builder shall expand the 3D ID map into corresponding 3D property maps for thermal conductivity (λ), density (ρ), and specific heat (Cp) using the material constants.

## 4. データエクスポート
- 4.1 The Model Builder shall provide a unified data structure containing the ID map, property maps, and coordinate vectors for downstream visualization and analysis modules.

## Scope Boundaries
- **In**: 全格子ループ処理、モジュール間のオーケストレーション、物性値の展開、非一様格子の算出。
- **Out**: 幾何学的な内外判定の詳細ロジック（`geometry-logic`が担当）、プロット描画（`validation-plot`が担当）。
