# Technical Design: model-builder

## 1. System Architecture & Component Design

### 1.1 ModelBuilder モジュール (Wrapper: modelA.jl) (Traceability: 1.1)
新モジュール群を統括し、オリジナルの `modelA.jl` のインターフェースを維持するためのラッパーとして機能する。

- `build_model(config, gds_layers, components) -> ModelData`: メインAPI。
- `expand_properties!(model_data, config)`: IDから物性値配列（λ, ρ, Cp）を生成。
- `modelA.jl`: エントリポイントとして `build_model` を呼び出し、後方互換性を維持する。

### 1.2 GridGenerator モジュール (Traceability: 2.1)
- `generate_z_grid(zm_markers, nk) -> Vector{Float64}`: `Zcoord.jl` を内部で呼び出し、オリジナルの `genZ!` ロジックを完全に再現する。
- `setup_coordinate_system(nxy, z_faces) -> CoordinateSystem`: セル中心、幅、外挿座標を含む全座標系の構築。ソルバーが要求する `nk+3` サイズの配列を生成する。

### 1.3 ハイブリッド幾何判定エンジン (Traceability: 3.1)
- **Sampling-based Kernel**: 円柱（TSV）や球（Bump）に対しては、オリジナルと同様に `samples=50` 程度のサンプリングによる占有率判定を行い、幾何学的な数値的一致を保証する。
- **GDS2-aware Kernel**: チップや熱源の複雑なポリゴンに対しては、`GdsMapping` と連携し、GDSII由来のポリゴン境界に基づく判定を行う。

### 1.4 データ構造 (ModelData) (Traceability: 4.1)
```julia
struct ModelData
    id_map::Array{UInt8, 3}      # サイズ: (NX+2, NY+2, NZ+2)
    lambda::Array{Float64, 3}
    rho::Array{Float64, 3}
    cp::Array{Float64, 3}
    coords::CoordinateSystem    # Z, z_centers, dz_grid 含む
end
```

## 2. Architecture Decisions & Integration

### 2.1 3Dマップの完全一致 (Traceability: 1.2)
- IDマップの生成において、浮動小数点演算の順序やサンプリング点をオリジナルと厳格に一致させ、`H2-main-original` とビットレベルで同一の出力を得る。
- これにより、ソルバーの収束性や残差の挙動がオリジナルと完全に一致することを保証する。

### 2.2 上書き禁止ルールの実装 (Traceability: 1.3)
1. `ID` 配列を `0` で初期化。
2. **Phase 1 (HeatSource/PG)**: 熱源を優先充填。
3. **Phase 2 (TSV)**: シリコン層内の ID が 0 または Silicon の箇所を TSV ID で上書き（チップ構成に依存）。
4. **Phase 3 (Silicon/Base)**: 土台やチップ本体を充填。
5. **Phase 4 (Solder Bump)**: Resin 充填後または ID=0 の箇所にバンプを配置。
6. **Phase 5 (Resin)**: 最終的に残った `ID == 0` を樹脂で埋める。
※ オリジナルの `modelA.jl` の充填順序を厳格に踏襲する。

### 2.3 座標系とソルバー互換性 (Traceability: 2.2)
- ガイドセル（+2サイズ）の維持。
- 外挿座標（nk+3）の線形補間ロジックの継承。
- セル中心（z_centers）の算出式の維持。

## 3. Boundary Commitments
- **Owned**: 3D配列のライフサイクル管理、格子座標計算、物性値の展開、統合ループ、オリジナル互換インターフェース。
- **Not Owned**: 形状ごとの数学的判定の個別実装（`GeometryLogic` に委譲）、配置座標の決定（`ComponentGenerator` に委譲）。

## 4. File Structure Plan
- `src/ModelBuilder/ModelBuilder.jl`: メイン統合ロジック。
- `src/ModelBuilder/Grid.jl`: `Zcoord.jl` 連携を含む座標系生成。
- `src/ModelBuilder/Mapper.jl`: IDから物性値への変換。
- `src/modelA.jl`: 後方互換ラッパー。

## 5. Testing Strategy
- **Regression Tests**:
  - `H2-main-original` と同一パラメータでの ID マップの完全一致確認（Bit-identical check）。
- **Integration Tests**:
  - `ConfigLoader` から渡された `zm` 定数を用いて、期待通りの Z 格子が生成されるかの検証。
