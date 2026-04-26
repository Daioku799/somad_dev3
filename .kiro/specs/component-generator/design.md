# Technical Design: component-generator

## 1. System Architecture & Component Design

### 1.1 ComponentGenerator モジュール
物理定数と配置ルールに基づき、検証済みのコンポーネントリストを生成する。

- `generate_components(config) -> Vector{GeometryObject}`: メインAPI。
- `calculate_safe_bump_radius(r_tsv, d_ufill) -> Float64`: 安全半径の算出。

### 1.2 データ構造 (Types)
- `GeometryObject`: 
  - `type::Symbol` (:cylinder, :sphere, :box)
  - `pos::NTuple{3, Float64}`: 中心座標 (x, y, z)
  - `dims::Dict{Symbol, Float64}`: 半径、高さ、寸法など
  - `mat_id::Int`: 材料ID

## 2. Architecture Decisions & Integration

### 2.1 垂直同期配置アルゴリズム (Traceability: 1.1, 2.1)
1. **座標生成**: モードに応じた共通 (x, y) リストを作成。
2. **TSV生成**:
   - Chip 1-3 の各 Z 範囲 ([zm2, zm4], [zm5, zm7], [zm8, zm10]) に対して `Cylinder` を作成。
3. **バンプ生成**:
   - UF 1-4 の各中心 Z 座標 (zm1.5, zm4.5, zm7.5, zm10.5 相当) に対して `Sphere` を作成。
   - 安全半径 $R$ を全バンプに適用。

### 2.2 物理バリデーションロジック (Traceability: 4.1, 4.2)
- **境界チェック**: 全オブジェクトの `x ± r`, `y ± r` がチップ領域内に収まっているか。
- **干渉チェック**: 全ての TSV 中心ペア $(p_i, p_j)$ に対して $dist(p_i, p_j) \ge 2 \times r_{tsv}$ を検証。

## 3. Boundary Commitments
- **Owned**: コンポーネント座標の算出、安全半径の適用、物理干渉の検証。
- **Not Owned**: 点判定の数学ロジック（`geometry-logic`が担当）、GDS形状の管理。

## 4. File Structure Plan
- `src/ComponentGenerator/ComponentGenerator.jl`: メインAPIとオブジェクト構築。
- `src/ComponentGenerator/Layout.jl`: 座標リスト生成ロジック。
- `src/ComponentGenerator/Validator.jl`: 物理制約チェック。

## 5. Testing Strategy
- **Unit Tests**:
  - `random` 配置時のシード再現性。
  - 安全半径公式の算出結果が理論値と一致するか。
  - 干渉している座標セットを与えた際に正しくエラーが検出されるか。
- **Integration Tests**:
  - 生成されたオブジェクトリストを `geometry-logic` に渡して矛盾なく判定できるか。
