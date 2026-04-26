# Requirements: model-builder

## 1. モデル構築の統合と数値的一致
- 1.1 The Model Builder shall orchestrate `ConfigLoader`, `GdsMapping`, `ComponentGenerator`, and `GeometryLogic` to construct the full 3D simulation domain.
- 1.2 **[絶対条件: 数値的一致]** The Model Builder shall produce 3D ID maps and property maps that are bit-for-bit identical to `H2-main-original` when provided with equivalent input parameters. This is critical for solver convergence.
- 1.3 **[上書き禁止ルールの厳守]** When filling the 3D ID map, the Model Builder shall process components in the exact order specified in `modelA.jl` (PowerGrid > TSV > Silicon > Solder > Resin) and only fill cells that have an ID of zero.

## 2. 座標系とソルバー互換性
- 2.1 **[Zcoord.jl の流用]** The Model Builder shall use or perfectly replicate the `genZ!` logic from `H2-main-original/src/Zcoord.jl`, ensuring the Z coordinate vector has size `nk+3` with linear extrapolation at both ends.
- 2.2 **[ガイドセルの維持]** The Model Builder shall maintain the exact ghost/boundary cell structure (+2 per dimension) and cell-center calculation expected by the original heat solver.

## 3. 幾何判定の統合
- 3.1 **[判定ロジックの継承]** For primitives (Cuboid, Cylinder, Sphere), the Model Builder shall use the exact sampling-based logic from `modelA.jl` (e.g., `is_included_cyl` with `samples=50`) to ensure geometric consistency.
- 3.2 The Model Builder shall apply BBox-based range optimization for each component to minimize the number of calls to the geometry engine.
- 3.3 The Model Builder shall expand the 3D ID map into corresponding 3D property maps using the material constants, ensuring property indices match original definitions.

## 4. データ構造の互換性
- 4.1 The Model Builder shall provide data structures (`ID`, `λ`, `ρ`, `Cp`, `Z`, `z_centers`, `dz_grid`) that are directly consumable by the original `heat3ds.jl` without modification.

## Scope Boundaries
- **In**: 全格子ループ処理、モジュール間のオーケストレーション、物性値の展開、オリジナル準拠の座標計算。
- **Out**: GDSII由来の複雑形状判定（`gds-mapping`および`geometry-logic`が担当）、プロット描画（`validation-plot`が担当）。
