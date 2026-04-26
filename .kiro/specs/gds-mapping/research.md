# Research Log: gds-mapping

## Summary
既存の `PolygonOps.jl` の挙動を調査し、境界線上（戻り値 0.5）を含めた安定した判定が必要であることを確認した。また、判定の高速化のために BBox フィルタリングが有効であり、データロード時にこれを事前計算する設計が最適であることを再確認した。

## Research Log Topics

### Topic 1: PolygonOps.inpolygon の挙動
- **Findings**:
  - `1.0`: 内部、`0.0`: 外部、`0.5`: 境界上。
  - 実装では `>= 0.5` を用いることで、微小な格子が境界に掛かった際にも「包含」としてカウントする方針を維持する。

### Topic 2: 幾何学的安定性の確保
- **Findings**:
  - GDSII データには微小なセグメントや重複頂点が含まれることがあり、これが `PolygonOps` の判定エラー（不安定な挙動）を招く可能性がある。
  - ロード時に Tolerance（許容誤差）ベースでの頂点マージを行うことで、計算の安定性を高める。

## Architecture Decisions

### Decision 1: 層ごとのポリゴン集約 (Aggregation)
- **Rationale**: モデル構築時（model-builder）は「特定の点 (x, y) がその層に含まれるか」のみを知れば良いため、ポリゴン個別の判定ではなく、層（Layer）単位での判定インターフェースを提供する。

### Decision 2: 座標系の一元変換
- **Rationale**: `SimpleGDS.jl` は um 単位の整数/実数を返すが、解析全体は m 単位で行う。モジュールの入り口で一括変換することで、単位系の混在によるバグを防止する。

## Risks & Mitigations
- **Risk**: 巨大な GDSII ファイル（数万頂点）による判定速度の低下。
- **Mitigation**: ポリゴンごとの BBox 早期棄却に加え、将来的には Spatial Index（四分木等）の導入を検討可能なデータ構造にする。
