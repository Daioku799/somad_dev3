# Technical Design: model-builder

## 1. System Architecture & Component Design

### 1.1 ModelBuilder モジュール
各モジュールを統括し、解析用データ一式（ModelData）を構築する。

- `build_model(config, gds_layers, components) -> ModelData`: メインAPI。
- `expand_properties!(model_data, config)`: IDから物性値配列（λ, ρ, Cp）を生成。

### 1.2 GridGenerator モジュール
- `generate_z_grid(layers, pg_dpth) -> Vector{Float64}`: 物理的な格子面（faces）の算出。
- `setup_coordinate_system(nxy, z_faces) -> CoordinateSystem`: セル中心、幅、外挿座標を含む全座標系の構築。

### 1.3 データ構造 (ModelData)
```julia
struct ModelData
    id_map::Array{UInt8, 3}
    lambda::Array{Float64, 3}
    rho::Array{Float64, 3}
    cp::Array{Float64, 3}
    coords::CoordinateSystem
end
```

## 2. Architecture Decisions & Integration

### 2.1 不等間隔格子の構築 (Traceability: 2.1)
1. `z_markers` (zm0-12) を基点とする。
2. 各層内部で `divisions` に基づき分割点を挿入。
3. `grading` に従い、境界付近に点を寄せる。
4. 前後に `2*face[1] - face[2]` 等の線形外挿を行い、ソルバー用座標ベクトルを完成させる。

### 2.2 ID 充填プロセス (Traceability: 1.2, 1.3, 3.1)
1. `ID` 配列を `0` で初期化（サイズ: $NXY+2, NXY+2, NZ+2$）。
2. **Phase 1 (PG)**: `GeometryLogic.is_included_gds` で熱源を充填。
3. **Phase 2 (TSV)**: `GeometryLogic.is_included_cylinder` で TSV を充填。
4. **Phase 3 (Base)**: 直方体、球体（バンプ）を順次充填。
5. **Phase 4 (Resin)**: 残った `ID == 0` のセルを樹脂 ID で埋める。

### 2.3 BBox 最適化 (Traceability: 3.2)
各コンポーネントの適用時、その BBox を格子インデックス $(i, j, k)$ に変換し、該当範囲のセルのみをループ処理する。

## 3. Boundary Commitments
- **Owned**: 3D配列のライフサイクル管理、格子座標計算、物性値の展開、統合ループ。
- **Not Owned**: 形状ごとの数学的判定（`GeometryLogic`）、配置座標の決定（`ComponentGenerator`）。

## 4. File Structure Plan
- `src/ModelBuilder/ModelBuilder.jl`: メイン統合ロジック。
- `src/ModelBuilder/Grid.jl`: 座標系生成ロジック。
- `src/ModelBuilder/Mapper.jl`: IDから物性値への変換。

## 5. Testing Strategy
- **Regression Tests**:
  - `H2-main-original` と同一パラメータでの ID マップの完全一致確認。
- **Integration Tests**:
  - 全モジュールを連結し、不正なJSONからエラー終了、正常なJSONから `ModelData` 生成までのフロー。
