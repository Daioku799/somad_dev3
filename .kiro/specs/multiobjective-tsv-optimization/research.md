# 多目的TSV最適化 設計調査・判断記録

## Summary

- **Feature**: `multiobjective-tsv-optimization`
- **Discovery Scope**: 既存FVM、配置生成、POD-RBF ROM、単目的GAを横断するComplex Integration
- **Key Findings**:
  - 現行FVMの面係数は調和平均熱伝導率と中心間距離を組み合わせており、両側半幅が異なり、かつ熱伝導率も異なる一般面では、要件3.2の直列熱抵抗式と一致しない。二つの物理セルを結ぶ内部面には、FVMと`gmax`の両方が呼ぶ単一の面コンダクタンス演算子が必要である。外部境界面はDirichlet/Neumann/Robin専用演算子で扱う。
  - 現行`grad3d_max`は単純中心差分、現行`TmaxEvaluator`は一部行評価である。どちらも新目的定義の正本としては再利用せず、旧成果物とともに`LEGACY_UNVERIFIED`として残す。
  - 現行`PipelineData`、`PipelineROM`、`SearchOptimizer`の支配判定、`PipelineReport`のrun境界は再利用できる。一方、整数dataset、候補固有物理場、NSGA-II、validation gate、cache/archive、hypervolume、代表点選定、可視化は新しい責務境界が必要である。
  - 新規外部依存は不要である。現行のJulia標準ライブラリと`Distributions`、`JLD2`、`JSON3`、`Plots`で要件を満たせる。
  - `numerical-vv`は未設計であるため、解析試験の許容誤差、FVM収束、エネルギー収支は型付きpolicyとして必須入力にし、承認済みpolicy IDがない限りdataset生成をfail closedにする。

## Research Log

### FVM面コンダクタンスと非一様格子

- **Context**: `gmax`はFVMと同じ面コンダクタンスを使い、異材界面の材料側勾配を再構成する必要がある。
- **Sources Consulted**:
  - `H2-main-ext/src/common.jl`
  - `H2-main-ext/src/NonUniform.jl`
  - `H2-main-ext/src/ModelBuilder/Grid.jl`
  - [NIST FiPy finite-volume discretization](https://pages.nist.gov/fipy/en/3.4.5/numerical/discret.html)
- **Findings**:
  - 現行`Common.λf`は熱伝導率の調和平均を返し、`NonUniform.jl`の複数kernelが面積と中心間距離を別に掛けている。
  - この構成は両側半幅が等しい、または両材料の熱伝導率が等しい場合には直列熱抵抗式と一致するが、一般の非対称異材面では一致しない。
  - 同じ係数計算が複数solver kernelへ重複しているため、目的評価器だけを直すとFVMとの演算子一致を保証できない。
- **Implications**:
  - `internal_face_conductance(area,d_p,d_n,k_p,k_n)`を純粋関数として一箇所へ抽出する。
  - FVM全kernelとROM/FVM共通目的評価器は物理セル間の内部面に限ってこの関数を使用する。外部境界面へghost cellを介して適用しない。
  - 従来式との一致、非対称異材面の独立計算、solver係数との同一性を別々に検証する。

### 温度場、材料場、格子情報の契約

- **Context**: `Tmax`と`gmax`を候補固有の全物理セルから計算し、異なる候補・格子の混入を拒否する必要がある。
- **Sources Consulted**:
  - `H2-main-ext/src/heat3ds.jl`
  - `H2-main-ext/src/ModelBuilder/ModelBuilder.jl`
  - `H2-rom/src/PipelineData/loader.jl`
- **Findings**:
  - snapshotは`theta`、`id_map`、`lambda`、z座標、格子数、`mu`、限定的な`config_summary`を保存する。
  - case ID、layout/grid signature、完全な物理条件、収束状態、エネルギー収支が不足している。
  - `PipelineData`は温度場を物理セルへ切り出すが、目的評価に必要な材料場・熱伝導率場・格子幾何を保持しない。
  - solver未収束とsnapshot保存失敗が警告に留まり、研究pipelineを停止しない経路がある。
- **Implications**:
  - `FieldBundle`は温度、材料ID、熱伝導率、格子幾何、case/layout/grid signature、単位、品質状態を不可分に扱う。
  - FVM snapshot schemaをversion化し、読み込み時に全signatureとshapeを照合する。
  - 未収束、非有限、エネルギー収支不合格、保存失敗をdataset適格状態へ昇格させない。

### 整数TSV配置と実座標

- **Context**: canonical設計変数は16成分の整数本数であり、固定総数と実配置制約を決定的に保つ必要がある。
- **Sources Consulted**:
  - `H2-main-ext/src/ComponentGenerator/Layout.jl`
  - `H2-main-ext/src/ComponentGenerator/Validator.jl`
  - `.kiro/specs/component-generator/design.md`
- **Findings**:
  - 現行APIは連続密度`mu`をcapacityへ掛け、roundと総数scaleを行う。既に実行可能な整数countsを正本として渡すAPIはない。
  - 基準4×4、直径40 µm、最小ピッチ80 µmの現行実装領域では各セルcapacity 9を構成できる。
  - 各セル内候補は中心距離順だが、等距離時の規則が公開契約になっていない。
  - 物理制約検証を迂回してFVMを呼べる経路がある。
- **Implications**:
  - `expand_integer_counts`はcountsを再scaleせず、長さ、0..9、総数、座標数、有限性、領域、pitchを検証する。
  - セル内座標は`(中心距離二乗, y index, x index)`の昇順で固定する。
  - layout signatureはJulia process依存の`hash`ではなく、整数counts、配置規則version、直径、pitch、canonical実座標をSHA-256化する。

### Datasetとsplit独立性

- **Context**: 444通常配置と21 stress配置を、用途漏洩なく生成する必要がある。
- **Sources Consulted**:
  - `runs/paper_final_20260824T0140JST/gen_cases.py`
  - `H2-rom/src/PipelineData/`
  - `H2-rom/src/SnapshotGenerator/`
- **Findings**:
  - 旧generatorはDirichlet混合と36/48/60水準の一部を持つが、424件、確率的余り配分、限定的interpolation水準であり、新契約とは一致しない。
  - snapshot ID、layout signature、実配置のsplit横断重複検査、stress set、OOD modelがない。
  - 16セル、上限9、総数60以下の整数射影は、小さい動的計画法で厳密解と辞書順tie-breakを得られる。
- **Implications**:
  - 新`LayoutDataset`が生成、整数射影、stress候補列、重複audit、OOD modelを所有する。
  - dataset manifestを生成してからFVMを起動し、IDまたはsignature重複を事前・事後の両方で拒否する。

### POD-RBF ROMと候補固有評価

- **Context**: ROM場へFVM場と同じ`Tmax`・`gmax`評価器を適用する必要がある。
- **Sources Consulted**:
  - `H2-rom/src/PipelineROM/`
  - `H2-rom/src/ROMInterpolator/`
  - `H2-rom/src/ROMValidator/`
- **Findings**:
  - `PipelineROM.build_rom`は明示train indexだけで学習し、`predict_field`は全物理セル温度場を再構成できる。
  - `select_settings`は現状`Tmax MAE`だけで選ぶ。新要件では`Tmax`と`gmax`双方のvalidation性能を扱う必要がある。
  - 限定行版`TmaxEvaluator`は新要件で使用できない。
  - 候補固有材料場はTSV配置で変化するため、ROM温度場だけでは`gmax`を評価できない。
- **Implications**:
  - `ModelBundle`へmodel/dataset/split/grid/objective definition/physics config IDとOOD modelを束縛する。
  - candidate countsから実配置と材料場を決定的にmaterializeし、ROM全場と組にして共通評価器へ渡す。
  - hyperparameter候補集合は設定入力とし暗黙既定値を持たない。validation上の本数別・目的別正規化誤差の最大値を最小化し、同点は少ないPODモード、強い正則化、epsilon昇順で決定する設計案とする。

### 多目的探索と比較指標

- **Context**: 固定本数2目的と可変本数3目的を同じNSGA-II枠組みで扱い、同予算random baselineと比較する。
- **Sources Consulted**:
  - `H2-rom/src/GaOptimizer/`
  - `H2-rom/src/SearchOptimizer/`
  - [Deb et al. NSGA-II](https://doi.org/10.1109/4235.996017)
  - [Zitzler and Thiele hypervolume study](https://doi.org/10.1109/4235.797969)
- **Findings**:
  - 現行`GaOptimizer`は`Vector{Float64}`、scalar fitness、BLX-α、Gaussian mutationであり、整数NSGA-IIの土台として継ぎ足すと境界が曖昧になる。
  - `SearchOptimizer.dominates`と`non_dominated`は支配定義として再利用できるが、NSGA-IIではない。
  - 現行依存に進化計算・hypervolume packageはない。問題固有の修復、cache、budget accountingがあるため、小さい専用実装の方が契約を明示しやすい。
- **Implications**:
  - `NSGA2Optimizer`を新設し、整数counts、rank、crowding distance、評価ledger、全履歴archiveを型で分離する。
  - 2/3目的だけを対象に、正規化済み非劣集合の2D/3D hypervolumeを決定的に計算する。
  - physical cacheと論理run別unique evaluation countを別状態にする。

### 来歴、可視化、旧成果物

- **Context**: FVM再評価済み点とROM予測点を区別し、claimから入力まで追跡可能にする必要がある。
- **Sources Consulted**:
  - `H2-rom/src/PipelineReport/`
  - `.kiro/specs/paper-rom-pipeline/design.md`
  - `.kiro/steering/roadmap.md`
- **Findings**:
  - 現行`RunProvenance`はdataset、件数、POD/RBF設定、seed、警告を持つが、候補単位のsignature、目的定義、探索予算、FVM状態を持たない。
  - `Plots.jl`は既存依存で、要求される2D/3D散布図を生成できる。
  - 旧424件dataset、旧`grad3d_max`、ε主探索は新要件と競合する。
- **Implications**:
  - run manifest、dataset manifest、model manifest、candidate ledgerを分け、IDで結ぶ。
  - 図と同じ点集合をTSV/JSONへ保存し、ROM/FVM、支配状態、selection slotを列として持つ。
  - 旧成果物は移動・削除・上書きせず、品質状態だけを`LEGACY_UNVERIFIED`として参照する。

### External dependency verification

- **Context**: NSGA-II、Spearman、hypervolumeに外部packageを追加するかを判断する。
- **Sources Consulted**:
  - `H2-rom/Project.toml`、`H2-main-ext/Project.toml`、両Manifest
  - 外部package公式資料のweb検索（設計判断を変える必須packageは確認されなかった）
- **Findings**:
  - `Random`、`Statistics`、`LinearAlgebra`、`SHA`と既存`Distributions`、`JLD2`、`JSON3`、`Plots`で必要機能を構成できる。
  - 特殊な整数修復と論理run別budget accountingは汎用NSGA-II packageへ載せても独自層が必要になる。
- **Implications**:
  - 新規依存を追加しない。Spearman rank、2D/3D hypervolume、NSGA-IIは対象範囲を限定した型付き実装と決定的試験で保証する。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Decision |
|---|---|---|---|---|
| 旧run script拡張 | `runs/...`の既存scriptへ処理を追加 | 初期変更が小さい | 条件直書き、再利用不能、来歴分散 | 不採用 |
| 現行GaOptimizer拡張 | 実数単目的GAへrank等を追加 | GA loopの一部を再利用 | 遺伝子・fitness・演算子契約が逆で複雑化 | 不採用 |
| 外部NSGA-II package | 汎用実装を採用 | 基本algorithmを再利用 | 独自修復、cache、budget契約とのadapterが大きい | 不採用 |
| Boundary-first pipeline | 純粋domain moduleとrun coordinatorを分離 | fail-closed、試験可能、来歴明瞭 | 新しい型とmoduleが必要 | 採用 |

## Design Decisions

### Decision: 面コンダクタンスをFVM側の単一正本にする

- **Context**: FVMと`gmax`が異なる式を使うと物理整合性を主張できない。
- **Alternatives Considered**: 旧`λf`維持、目的評価器だけ直列抵抗化、共有helper化。
- **Selected Approach**: 物理セル間の内部面では`ThermalOperators.internal_face_conductance`をFVM全kernelと目的評価器が使用する。外部6面はDirichlet/Neumann/Robin別の境界演算子を使い、energy balanceもその符号付き境界熱流を集計する。
- **Rationale**: 4.6の同値試験を構造的に可能にし、式の重複をなくす。
- **Trade-offs**: solver係数が変化する可能性があり、旧結果は再検証が必要。
- **Boundary condition preservation**: 外部Robin境界は現行FVMの`hA(T_P-T_inf)`離散化を保存する。半セル伝導抵抗の追加は数値モデル変更になるため本specでは採用せず、必要なら別要件と独立V&Vへ送る。
- **Follow-up**: 解析場試験とFVM convergence/energy gateが通るまでdataset生成禁止。

### Decision: 整数countsをcanonical設計入力にする

- **Context**: 総数保存と各セル上限を確実に扱う必要がある。
- **Selected Approach**: 全pipeline入口を`NTuple{16,Int}`相当の整数countsとし、連続表現はROM scaler内部に限定する。
- **Trade-offs**: 旧`mu` artifactとの直接互換性は持たない。
- **Follow-up**: 旧入力は明示migrationなしに新datasetへ混ぜない。

### Decision: validation gateを三値状態にする

- **Context**: 設計幅0や定数順位をPASS/FAILだけで表せない。
- **Selected Approach**: `PASS`、`FAIL`、`INCONCLUSIVE`、配置外挿用`UNSUPPORTED`を明示し、gateはPASS以外で停止する。
- **Trade-offs**: pipeline状態遷移が増えるが、暗黙継続を防げる。

### Decision: 専用整数NSGA-IIを新設する

- **Context**: 旧GAは連続単目的である。
- **Selected Approach**: 支配定義だけ再利用し、population、演算子、ledger、archiveを新moduleで所有する。
- **Trade-offs**: algorithm試験が必要だが、要件固有契約を直接表現できる。

### Decision: 物理cacheと評価予算を分離する

- **Context**: 同じlayoutのROM/FVM結果再利用と、公平な論理run予算を両立する必要がある。
- **Selected Approach**: content-addressed physical cacheと、runローカル`EvaluationLedger`を別aggregateにする。
- **Trade-offs**: 記録量が増えるが、11.4–11.5を監査可能にする。

### Decision: 新規外部依存を追加しない

- **Context**: 依存固定と特殊契約を優先する。
- **Selected Approach**: 現行依存・標準ライブラリ上で限定実装する。
- **Trade-offs**: NSGA-II/HVの単体・property testを自前で充実させる必要がある。

## Risks & Mitigations

- 面係数変更でFVM温度場が旧結果から変わる — 旧artifactを上書きせず、解析検証と新runだけで評価する。
- 候補ごとの材料場生成と全場再構成が探索時間を支配する — layout/physics/objective cacheを使い、100–1000候補benchmark後にのみpilotを承認する。
- 444場の一括常駐でmemoryが増える — POD学習温度行列と検証時の候補物理場を分離し、材料場を逐次読み込みする。
- `numerical-vv`未確定 — policy IDを必須にし、承認済み値がない場合はdataset生成を停止する。
- hyperparameter選択が二目的で不明瞭 — validationの最悪正規化誤差を最小化する提案をdesign承認対象として明示する。
- stress scoreと遺伝演算子の詳細が結果へ影響する — designに完全な順序とtie-breakを記録し、承認後にconfigを凍結する。
- 旧成果物との混同 — schema version、quality state、run/dataset/model IDを全出力へ持たせる。

## References

- [承認済み要件](requirements.md)
- [理論・採用根拠](theory-and-rationale.md)
- [NSGA-II原論文](https://doi.org/10.1109/4235.996017)
- [Hypervolumeを含む集合評価](https://doi.org/10.1109/4235.797969)
- [NIST FiPy finite-volume method](https://pages.nist.gov/fipy/en/3.4.5/numerical/discret.html)
- `H2-main-ext/src/NonUniform.jl`
- `H2-main-ext/src/heat3ds.jl`
- `H2-main-ext/src/ComponentGenerator/`
- `H2-rom/src/PipelineData/`
- `H2-rom/src/PipelineROM/`
- `H2-rom/src/SearchOptimizer/`
- `H2-rom/src/PipelineReport/`
