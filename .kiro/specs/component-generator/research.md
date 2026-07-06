# Research Log: component-generator

## Summary
3D-IC of 物理構造に基づき、TSVとバンプの垂直同期を数学的に保証する設計を調査した。また、密度マップ（mu）から実TSV座標を生成するデコードロジックの物理的整合性を検証した。

## Research Log Topics

### Topic 1: 密度マップ（mu）からの座標展開
- **Context**: 次数低減モデル（ROM）のパラメータである密度ベクトル `mu` を物理的なTSV座標へ変換する。
- **Findings**:
  - チップ領域 $(l_x, l_y)$ を $G_x \times G_y$ のセルに分割する。
  - 各セル $(i, j)$ において、最小ピッチ $p_{min}$ を維持しながら配置可能な最大本数 $n_{max,ij}$ を算出する。
  - $n_{ij} = \text{round}(\rho_{ij} \times n_{max,ij})$ を配置本数とし、セル内で中央寄せの格子配置を行う。
- **Implications**: 密度マップ形式であっても、物理的なピッチ制約（$p_{min}$）を厳密に守る展開ロジックが必要。

### Topic 2: 垂直方向の整合性 (Vertical Alignment)
- **Findings**: 
  - TSVはシリコン層 (zm2-4, 5-7, 8-10) に、バンプはアンダーフィル層 (zm1-2, 4-5, 7-8, 10-11) に配置される。
  - 同一の (x, y) 座標セットを全層のオブジェクト生成に適用することで、スタックとしての整合性を担保する。

### Topic 3: 安全半径の計算タイミング
- **Findings**:
  - TSVの半径 $r_{tsv}$ とアンダーフィル厚さ $d_{ufill}$ が確定した直後に、$R = \sqrt{r_{tsv}^2 + (d_{ufill}/2)^2}$ を計算する。
  - この値は、はんだバンプの「最小許容半径」として、生成される全バンプオブジェクトに適用される。

## Architecture Decisions

### Decision 1: オブジェクト指向のコンポーネント管理
- **Rationale**: 3Dグリッドへの直接書き込みを避け、一旦「幾何形状オブジェクト」のリストとして抽象化することで、`geometry-logic` との結合を疎にし、物理バリデーション（干渉チェック等）を容易にする。

### Decision 2: 密度展開ロジックの独立化
- **Rationale**: `Layout` モジュール内に、`manual`, `random` に加えて `density` モードを独立したロジックとして実装することで、将来的な配置アルゴリズム（例：ランダム密度配置）の拡張性を確保する。

### Decision 3: 干渉チェックの先行実施
- **Rationale**: モデル構築（充填）は重い処理であるため、充填を開始する前に全座標の干渉（TSV同士の重なり）を確認し、不正な配置を早期に弾く。

## Risks & Mitigations
- **Risk**: 密度マップからの展開において、セル境界付近でのTSV同士の干渉。
- **Mitigation**: セル内の有効配置領域を（セル境界 - $p_{min}/2$）として定義し、隣接セル間のTSVが最小ピッチを割り込まないようにガードをかける。
- **Risk**: ランダム配置において、TSV本数が多い場合に干渉チェックで無限ループや生成不能に陥る可能性。
- **Mitigation**: 最大試行回数を設定し、配置不能な場合はエラーを投じてユーザーにピッチや本数の再検討を促す。

---

## Gap Analysis: TSV Placement Restriction to Silicon Domain

### 1. Current State & Codebase Assets
* **`H2-main-ext/src/ComponentGenerator/Layout.jl`**:
  * 密度マップ配置モード (`config.mode == :density`) では、すでにチップ外周から `0.1e-3` (0.1mm) のマージンを差し引いたシリコン実装領域（`[0.1e-3, lx - 0.1e-3] × [0.1e-3, ly - 0.1e-3]`）を基準にしてセル分割と配置点の生成が行われている。
  * しかし、`:manual` や `:random` 配置モードでは、このシリコン領域マージンの検証や制限が座標展開時（`expand_coordinates`）には行われていない。また、`0.1e-3` という値がハードコードされており、一元管理されていない。
* **`H2-main-ext/src/ComponentGenerator/Validator.jl`**:
  * `validate_physical_constraints` が境界チェックを行う際、チップサイズ `lx`, `ly` および `radius` のみを基準に判定している (`pt.x < radius || pt.x > lx - radius`)。
  * そのため、シリコン領域 `[0.1e-3, lx - 0.1e-3] × [0.1e-3, ly - 0.1e-3]` からTSV（半径を含む全体）がはみ出していても、境界エラーとして検出できない重大なギャップが存在する。
* **`H2-main-ext/test/` (Unit Tests)**:
  * `test_validator.jl` や `test_layout.jl` でのテスト用 `config` の作成時、`lx = 1.0e-3` のように小さなチップサイズが使われている箇所がある。ここに一律 `margin = 0.1e-3` を適用すると、TSVが配置される領域が極端に狭くなり、既存のテストケースで予期せぬ境界エラーや干渉エラーが発生するリスクがある。

### 2. Requirements-to-Asset Map & Identified Gaps
* **Requirement 2 (セル内での実TSV座標展開)**:
  * *Status*: **Constraint / Gap**
  * *Current Asset*: `Layout.jl`
  * *Detail*: `:density` モード以外でもシリコン実装領域の制約を尊重すべきか、および `margin = 0.1e-3` の一元管理方法について設計フェーズで決定する必要がある。
* **Requirement 4 (物理的制約の検証 - 境界判定の修正)**:
  * *Status*: **Missing**
  * *Current Asset*: `Validator.jl`
  * *Detail*: 境界チェックの判定基準をチップ端 `lx` から「シリコン領域境界 `lx - margin`」に変更し、TSVの物理的な範囲（中心座標 ± 半径）が完全にシリコン内に収まっていることを検証するロジックが未実装。
* **Tests**:
  * *Status*: **Constraint**
  * *Current Asset*: `test_validator.jl`, `test_layout.jl`
  * *Detail*: テストデータにおけるチップ寸法 `lx`, `ly` を `1.2e-3` 以上にするか、あるいはテスト内のマージン設定を可変にする等のテスト修正が必要。

### 3. Implementation Options
* **Option A: Extend Existing Components (Extend `Layout.jl` & `Validator.jl`) [Recommended]**
  * *Rationale*: `ComponentGenerator` の既存のレイアウト配置および検証ロジックを拡張するだけで要件を完全に満たせるため、最も自然。
  * *Trade-offs*:
    * ✅ 新たなファイル作成が不要で、既存のバリデーションフローにそのまま統合できる。
    * ❌ テストコード側のチップ寸法設定との競合に注意する必要がある（テストコードの修正を伴う）。
* **Option B: Create a Dedicated Boundary Module (e.g., `SiliconDomain.jl`)**
  * *Rationale*: シリコンの領域（マージン `0.1e-3`）の計算や内外判定を単一モジュールに切り出し、`Layout` と `Validator` から共通参照する。
  * *Trade-offs*:
    * ✅ 将来的にシリコン領域の仕様（GDS連携の復活や、可変マージン）が変更された場合の影響範囲を限定できる。
    * ❌ 今回のシンプルな仕様（固定マージン `0.1e-3`）に対しては、ややオーバーエンジニアリングになる。

### 4. Implementation Complexity & Risk
* **Effort**: **S (1-3 days)**
  * *Justification*: `Layout.jl` と `Validator.jl` の判定境界にマージン `0.1e-3` を正しく適用し、テストコード側のパラメータを整合させるだけであるため、作業規模は比較的小さい。
* **Risk**: **Low**
  * *Justification*: 新規技術や外部モジュールの導入はなく、既存の幾何判定コードの定数および数式の軽微な修正で対応できるため。
