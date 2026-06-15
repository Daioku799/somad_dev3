# Research & Design Decisions: rom-interpolator

## Summary
- **Feature**: rom-interpolator
- **Discovery Scope**: Complex Integration
- **Key Findings**:
  - POD係数の予測には、各モード（基底）に対して独立したRBF補間器、あるいは多出力RBFモデルが必要。
  - 密度マップ `mu` の各次元（グリッドセル）のスケールを揃えるためのデータスケーリング（Min-MaxまたはStandardization）が、RBFカーネルの計算（距離ベース）において重要。
  - `pod-engine` が出力する `pod_model.jld2` と、`snapshot-generator` が出力するスナップショットメタデータ（`mu` を含む）を紐付ける必要がある。

## Research Log

### RBF補間のアルゴリズム選定
- **Context**: 密度マップ（ベクトル）からPOD係数（ベクトル）への写像に最適なRBF実装を検討。
- **Sources Consulted**: Julia documentation, "Radial Basis Function Networks" theoretical papers.
- **Findings**: 
    - 基礎的なRBF（Gaussian, Multiquadric）は、重み行列 $W$ を $W = A \cdot \Phi^{-1}$ ( $\Phi$ はカーネル行列) で解くことで実装可能。
    - サンプル数が少ない場合、正則化項（Ridge regression）を追加することでオーバーフィッティングを抑制できる。
- **Implications**: 外部ライブラリへの過度な依存を避け、Juliaの行列演算能力を活かした軽量な独自実装（または `RadialBasisFunctions.jl` のラップ）を採用する。

### 入力データのデータスケーリング
- **Context**: 密度マップ `mu` のスケール調整。
- **Findings**: 
    - 密度マップの各セルは $0$ から最大本数までの値を取る。
    - RBFは距離ベースのカーネルを使用するため、特定次元のスケールが大きいと支配的になってしまう。
    - 全次元を $[0, 1]$ または平均 $0$・分散 $1$ に変換するデータスケーリングコンポーネントが必須。
- **Implications**: `ScalingParams` 構造体を定義し、学習時の統計量を保存して予測時に再利用する。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Multi-output RBF | 一つの行列演算で全係数を一括予測 | 計算効率が高い、コードが簡潔 | 全モードに同じカーネルパラメータ（ε等）が適用される | 今回の用途（POD係数補間）では一般的 |
| Per-mode RBF | モードごとに個別のRBFモデルを構築 | 各モードの特性に合わせてパラメータを調整可能 | モデルサイズと計算コストが増大する | - |

## Design Decisions

### Decision: 独自実装 RBF (Gaussian Kernel) の採用
- **Context**: 外部依存関係を最小限にしつつ、Juliaの行列演算を最大限活用する。
- **Selected Approach**: `LinearAlgebra` を用いた行列解法によるRBF実装。
- **Rationale**: Juliaでは `A \ B` (バックスラッシュ演算子) で効率的に最小二乗解を求められるため、RBFの重み計算は数行で記述可能。複雑なサロゲートライブラリを導入するコストより、透明性の高い実装を優先。
- **Trade-offs**: 高度なカーネルチューニング機能などは自身で実装する必要がある。

### Decision: `pod_model.jld2` との密結合
- **Context**: `rom-interpolator` は `pod-engine` の結果がないと機能しない。
- **Selected Approach**: `pod_model.jld2` を読み込み、そこにRBF重みを追加保存するか、あるいは別ファイル `rom_model.jld2` として保存する。
- **Rationale**: 予測時には「RBF重み」と「POD基底」の両方が必要。これらを一つのファイル（あるいは明確にリンクされたファイル群）で管理することで、`rom-validator` 等の運用を簡素化する。

## Risks & Mitigations
- サンプル不足による過学習 — 正則化項（λ）の導入による平滑化。
- 次元不一致 — 入力 `mu` のサイズと学習済みモデルの次元チェックを強化。
- 再構成後の最高温度評価 — FVMソルバーとの整合性確保のため、再構成ベクトルから直接 $T_{max}$ を算出する `get_tmax` 関数を導入。

## References
- [Radial basis function - Wikipedia](https://en.wikipedia.org/wiki/Radial_basis_function)
- [JLD2.jl Documentation](https://JuliaIO.github.io/JLD2.jl/stable/)
