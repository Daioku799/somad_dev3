# Requirements: gds-mapping

## 1. GDSIIデータの読み込みと同一形状の適用
- 1.1 The GDS Mapper shall read geometry data from specified GDSII files and extract polygons belonging to target layers.
- 1.2 The GDS Mapper shall convert all internal GDSII coordinates (um) to the standard unit (m) consistently.
- 1.3 **[同一形状の適用]** The GDS Mapper shall support applying the same geometry definition to all three silicon chip layers as the default configuration for this phase.

## 2. 幾何学的な妥当性の検証（品質保証）
- 2.1 When a polygon is loaded, the GDS Mapper shall verify that the polygon is closed (start and end points are identical).
- 2.2 If a polygon has fewer than 3 unique vertices, the GDS Mapper shall exclude it as a degenerate shape and notify the user.
- 2.3 When processing vertices, the GDS Mapper shall merge redundant vertices within a tolerance of 1e-12 meters to prevent geometric instability.
- 2.4 If any polygon's calculated bounding box exceeds the chip boundary defined in `config.json`, the GDS Mapper shall issue a range violation warning.

## 3. 高速化と点包含判定
- 3.1 The GDS Mapper shall maintain a pre-calculated Bounding Box (BBox) for each valid polygon.
- 3.2 The GDS Mapper shall provide a function to determine if a 2D point (x, y) is inside any of the extracted polygons.
- 3.3 When performing a point-in-polygon check, the GDS Mapper shall first use the BBox to filter out points clearly outside the shape.

## 4. 視覚的検証の支援
- 4.1 The GDS Mapper shall provide access to the full vertex list and BBox data of all valid polygons for external visualization modules.

## Scope Boundaries
- **In**: GDSIIパース、幾何学的妥当性検証、BBoxフィルタリング、点包含判定。
- **Out**: Z軸方向の判定（geometry-logicが担当）、複数チップでの異なるGDSの使い分け（本フェーズでは対象外）。
