# Requirements: snapshot-generator

## 1. パラメータサンプリングの自動生成
- 1.1 The Snapshot Generator shall generate multiple sets of simulation parameters based on Latin Hypercube Sampling (LHS) or a specified range/grid.
- 1.2 The Snapshot Generator shall support varying TSV-related parameters: radius ($r_{tsv}$), count ($N_{tsv}$), and $(x, y)$ coordinates.
- 1.3 The Snapshot Generator shall validate each generated parameter set against physical constraints (e.g., TSV-to-TSV distance, chip boundary) before execution.

## 2. FVMソルバーの一括実行制御
- 2.1 The Snapshot Generator shall orchestrate sequential or parallel execution of the FVM solver (`H2-main-ext/run.jl`) for each valid parameter set.
- 2.2 The Snapshot Generator shall generate a unique configuration JSON for each simulation case to drive the model builder.
- 2.3 While a simulation is running, the Snapshot Generator shall monitor the execution and enforce a maximum runtime (timeout) per case.
- 2.4 If a simulation fails to converge or terminates with an error, the Snapshot Generator shall log the failure and skip to the next case without stopping the entire process.

## 3. スナップショットデータの永続化
- 3.1 When a simulation completes successfully, the Snapshot Generator shall extract the 3D temperature field ($\theta$) and the corresponding input parameters.
- 3.2 The Snapshot Generator shall save the extracted data to `data/raw/` in JLD2 format using a unique and traceable naming convention (e.g., `snapshot_{timestamp}_{case_id}.jld2`).
- 3.3 The Snapshot Generator shall record the summary of all generated snapshots (metadata) in a central registry file (e.g., `manifest.json`).

## 4. 実行環境と管理
- 4.1 The Snapshot Generator shall ensure that each simulation case is executed in an isolated environment (or subdirectory) to prevent file overwriting and race conditions.
- 4.2 The Snapshot Generator shall provide a summary report at the end of the collection process, detailing the number of successful, failed, and skipped cases.

## Scope Boundaries
- **In**: パラメータ生成（LHS）、ソルバーの一括実行制御、エラーハンドリング、JLD2データ保存、メタデータ管理。
- **Out**: ソルバー本体（heat3ds.jl）の熱力学的アルゴリズム、POD基底の抽出（pod-engineが担当）。
- **Adjacent**: `model-builder` (シミュレーション実行の依存先), `config-loader` (設定ファイル形式の共有)。
