# Research & Design Decisions: ga-optimizer

## Summary
- **Feature**: ga-optimizer
- **Discovery Scope**: New Feature (GA-based optimization)
- **Key Findings**:
  - TSV密度マップ `mu` を遺伝子とするGAにおいて、総本数制約と密度上限制約を維持するための「正規化ステップ」が各世代で不可欠である。
  - ROM（RBF補間）は訓練データの凸包外（外挿）で精度が急落するため、外挿検知ロジックによる信頼性ガードが必要。
  - エリート個体（上位数件）に対しては、ROM評価だけでなく、実際にTSVを配置してFVMを実行する「真の検証」を自動で行うフローが物理的整合性の担保に必須。

## Research Log

### GA実装の選択肢 (Build vs Adopt)
- **Context**: 密度マップ `mu` は各要素が [0, 1] の連続値であり、かつ合計値が一定以下という総和制約を持つ。
- **Sources Consulted**: `Evolutionary.jl` documentation, Genetic Algorithm best practices for constrained optimization.
- **Findings**: `Evolutionary.jl` は多種多様なアルゴリズムをサポートしているが、ドメイン固有の制約（密度マップの正規化や配置禁止領域のゼロ埋め）を各操作（交叉・突然変異）の直後に差し込む必要がある。
- **Implications**: アルゴリズムの枠組みとして `Evolutionary.jl` の利用を検討しつつ、制約修正ロジックを独立した `ConstraintManager` として実装し、カスタムオペレータとして統合する。

### 信頼性管理と外挿検知
- **Context**: ROMの予測値のみで最適化を進めると、ROMが苦手な領域（外挿領域）に個体が集中するリスクがある。
- **Sources Consulted**: RBF interpolation error characteristics, POD-ROM validation strategies.
- **Findings**: RBFはサンプリング点からの距離が離れると急速に誤差が増大する。各セル密度 `mu_i` の最小・最大値だけでなく、多次元空間での距離（マハラノビス距離等）または凸包判定が理想だが、初期実装では各次元の範囲チェックとサンプリング点への近接性で簡易検知を行う。
- **Implications**: `ReliabilityManager` を設け、外挿フラグが立った個体にはペナルティを与えるか、FVM実行を強制する。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Service-Orchestrator | GAエンジン、制約マネージャ、信頼性マネージャを統括するサービス | 責務が明確で、ROM/FVMの切り替えロジックを隠蔽できる | 連携が複雑になる可能性がある | プロジェクト全体の構造と一致 |

## Design Decisions

### Decision: 密度マップの正規化アルゴリズム
- **Context**: 突然変異等により総TSV本数（`sum(mu) * TSV_MAX_PER_CELL`）が上限を超えた場合の処理。
- **Selected Approach**: 比例配分によるスケーリング（Soft normalization）。
- **Rationale**: 個々のセルの密度の相対的な比率を維持したまま、全体を制約内に収めることができるため。
- **Trade-offs**: 密度が非常に低いセルが消滅する可能性がある。

### Decision: エリート個体のFVM自動再検証フロー
- **Context**: ROMの最適解が物理的に正しいことを保証する。
- **Selected Approach**: 上位N個体に対して `Density -> Real Coordinates -> FVM` を実行。
- **Rationale**: 密度マップは抽象化された表現であり、実際のTSV配置（ピッチ等）での整合性はFVMでしか確認できないため。
- **Follow-up**: FVM実行は時間がかかるため、並列実行数や対象個体数の設定を `config-loader` で管理する。

## Risks & Mitigations
- ROMの精度不足による局所最適解へのトラップ — 突然変異率の調整と、定期的なFVMサンプル追加（将来的な拡張）。
- 外挿判定の誤検知 — 判定閾値をパラメータ化し、解析結果を見ながら調整可能にする。
- FVM実行による最適化時間の増大 — エリート個体数を制限し、非同期実行を検討する。

## References
- [Evolutionary.jl](https://wildart.github.io/Evolutionary.jl/stable/) — GAフレームワークの参考。
- [H2-rom Specification](../rom-interpolator/brief.md) — ROMインターフェースの前提。
