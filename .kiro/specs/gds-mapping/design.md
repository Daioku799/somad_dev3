# Technical Design: gds-mapping

## 1. System Architecture & Component Design

### 1.1 GdsMapping モジュール
GDSII データの抽出、検証、および点包含判定を担う上位モジュール。

- `load_gds_layer(path, layer_id) -> GdsLayer`: データの読み込みと品質保証を一括実行。
- `is_point_in_layer(layer, x, y) -> Bool`: 高速化された包含判定を提供。
- `get_plot_data(layer) -> Vector{Matrix{Float64}}`: プロット用にポリゴン頂点をエクスポート。 (Traceability: 4.1)

### 1.2 データ構造 (Types)
- `GdsPolygon`:
  - `vertices::Vector{Tuple{Float64, Float64}}`: 検証済み・単位変換済み頂点リスト。
  - `bbox::NTuple{4, Float64}`: (xmin, ymin, xmax, ymax)。
- `GdsLayer`:
  - `polygons::Vector{GdsPolygon}`: 所属するポリゴン群。
  - `combined_bbox::NTuple{4, Float64}`: レイヤー全体の境界。

## 2. Architecture Decisions & Integration

### 2.1 品質保証ロジック (Traceability: 2.1, 2.2, 2.3)
1. **単位変換**: um -> m (`* 1e-6`)。
2. **頂点クリーンアップ**: 
   - 同一座標の連続する頂点を除去。
   - 微小セグメント（長さ < 1e-12）の除去。
3. **閉路保証**: `vertices[end] == vertices[1]` を強制。
4. **縮退チェック**: 有効頂点数（閉じている場合は4、開いている場合は3）未満なら警告。

### 2.2 点包含判定アルゴリズム (Traceability: 3.2, 3.3)
1. レイヤー全体の BBox で判定。
2. 個別ポリゴンの BBox で判定。
3. `PolygonOps.inpolygon` (判定値 >= 0.5) で詳細判定。

### 2.3 形状共有と統合 (Traceability: 1.3)
- `load_gds_layer` で生成された `GdsLayer` オブジェクトを `model-builder` が保持し、Chip 1, 2, 3 の各層の判定時に同一のオブジェクトを参照することで形状の共有を実現する。

## 3. Boundary Commitments
- **Owned**: GDSIIパースのラップ、幾何学的妥当性の検証、2D点包含判定。
- **Not Owned**: 3D格子の充填、温度解析、GDSIIファイル自体の生成。

## 4. File Structure Plan
- `src/GdsMapping/GdsMapping.jl`: メインAPI。
- `src/GdsMapping/Types.jl`: 構造体定義。
- `src/GdsMapping/Validator.jl`: 幾何データ検証ロジック。

## 5. Testing Strategy
- **Unit Tests**:
  - 重複頂点や未閉路のポリゴンが正しく修正されるか。
  - 境界線上・頂点上での判定の一貫性。
  - `get_plot_data` がプロット可能な行列形式を返すか。
- **Integration Tests**:
  - `config.json` のチップ範囲外にポリゴンがある場合の警告検知。
