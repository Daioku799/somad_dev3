# Research Log: pod-engine

## Summary
`pod-engine` は、FVMスナップショット（温度場 $\theta$）から次数低減モデル（ROM）の核となるPOD基底を抽出する。スナップショットデータは `(242, 242, 33)` の3次元配列であり、これをベクトル化してスナップショット行列を構成する。計算には Julia 標準の `LinearAlgebra.svd` を使用し、累積寄与率（RIC）に基づき基底数を決定する。

## Research Log Topics

### 1. Codebase Analysis: Snapshot Structure
- **Source**: `/data/raw/*.jld2`
- **Data**: `theta` (Array{Float64, 3}) が主要な解析対象。
- **Size**: 1スナップショットあたり約1.9M要素（約15MB）。
- **Findings**: `nx`, `ny`, `nz` などのグリッド情報も含まれており、これらは全スナップショットで共通であることを前提とする（不整合チェックは必要）。

### 2. Technology Research: Julia SVD & Memory
- **Libraries**: `LinearAlgebra`, `JLD2`
- **Performance**: 
    - スナップショット数 $N$ が小さい（例: $N < 500$）場合、特異値分解は $O(M N^2)$ ($M$: 自由度) であり、行列 $X^T X$ を介した手法（Method of Snapshots）がメモリ効率的。
    - Julia の `svd` は LAPACK を使用しており、スリム型 (`full=false`) で高速に計算可能。
- **Memory**: $1.9M \times 100$ の行列は約1.5GB。通常の計算環境（16GB+ RAM）で十分処理可能。

### 3. Architecture Pattern: Pipeline Processing
- **Pattern**: バッチ処理型パイプライン。
- **Flow**: ファイル走査 → 行列構築 → SVD → 基底選択 → 射影 → 永続化。

## Design Decisions

### 1. Centered vs Non-Centered POD
- **Decision**: 平均温度場 $\bar{\theta}$ を減算する **Centered POD** をデフォルトとする。
- **Rationale**: 変動成分の抽出効率が高く、RBF補間の精度が向上しやすいため。再構成時に平均場を加算する必要があるため、平均場も保存対象に含める。

### 2. Method of Snapshots vs Direct SVD
- **Decision**: `svd(X)` (Direct SVD) を基本としつつ、メモリ制約が厳しい場合は `eigen(X'X)` への切り替えを検討可能とするが、初期実装は `svd(X, full=false)` とする。
- **Rationale**: 数値的安定性と実装の単純さを優先。

## Risks and Mitigations
- **Risk**: メモリ不足。
- **Mitigation**: 不要な中間行列の早期解放（`GC.gc()`）と、`JLD2` の遅延読み込みを活用する。
- **Risk**: スナップショットの格子不整合。
- **Mitigation**: 読み込み時に `nx, ny, nz` の一致を確認するバリデーションを実装。
