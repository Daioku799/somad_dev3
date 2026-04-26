# Requirements: component-generator

## 1. TSVコンポーネントの配置計算
- 1.1 The Component Generator shall use the same (x, y) coordinate list for all silicon chip layers (Chip 1, 2, 3) to ensure vertical alignment of the interconnect stack.
- 1.2 When the `manual` mode is selected, the Component Generator shall extract coordinates directly from the `tsv_config.json` parameters.
- 1.3 When the `random` mode is selected, the Component Generator shall generate (x, y) coordinates within the valid chip area using the specified `random_seed`.

## 2. はんだバンプの自動生成と安全半径
- 2.1 The Component Generator shall generate solder bump objects at the (x, y) coordinates of each TSV, positioned at the vertical center (Z-axis) of each Underfill layer (UF 1 to 4).
- 2.2 The Component Generator shall calculate the solder bump radius $R$ using the formula $R = \sqrt{r_{tsv}^2 + (d_{ufill}/2)^2}$ to ensure complete coverage of the TSV end-faces.

## 3. 幾何オブジェクトリストの提供
- 3.1 The Component Generator shall provide a unified list of geometric objects (Cylinders for TSVs, Spheres for Bumps) containing their coordinates, dimensions, and material IDs.
- 3.2 The Component Generator shall provide the geometry data in a format compatible with the `geometry-logic` module's input requirements.

## 4. 物理的制約の検証（品質保証）
- 4.1 If any generated component (TSV or Bump) exceeds the chip boundaries defined in `config.json`, the Component Generator shall raise a boundary violation error.
- 4.2 If the distance between any two TSV centers is less than the TSV diameter ($2 \times r_{tsv}$), the Component Generator shall notify the user of a physical interference violation.

## Scope Boundaries
- **In**: TSV/バンプの座標生成、安全半径の算出、形状オブジェクトのリスト化、干渉チェック。
- **Out**: IDマップへの具体的な充填（`model-builder`が担当）、幾何判定（`geometry-logic`が担当）。
