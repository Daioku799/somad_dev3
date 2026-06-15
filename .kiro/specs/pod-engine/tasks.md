# Implementation Plan - pod-engine

## Tasks

- [ ] 1. Foundation: Module Structure and Data Types
  - `H2-rom/src/PODEngine/PODEngine.jl` および `types.jl` の作成。
  - `PODModel` 構造体の定義（basis, singular_values, coefficients, mean_field, snapshot_ids, mu_vectors, metadata を保持）。
  - metadata 内に `trained_snapshot_ids` および格子情報（nx, ny, nz, dx, dy, dz, lx, ly, lz）を含める準備。
  - 必要な依存パッケージ（LinearAlgebra, JLD2, Statistics）のインポート設定。
  - _Requirements: 4.1, 4.2_

- [ ] 2. Snapshot Loading and Grid Validation
- [ ] 2.1 (P) Snapshot Loader Implementation
  - `loader.jl` の実装。`JLD2` を用いて指定ディレクトリ内のスナップショットファイルを走査・ロード。
  - `snapshot_ids`（ファイル名等）および `mu` ベクトルの抽出ロジック追加。
  - 3次元温度場 `theta` のベクトル化（flatten）処理の実装。
  - `load_snapshot_matrix` が行列に加え、IDリスト、パラメータ行列、格子情報を返すことを確認。
  - _Requirements: 1.1_
  - _Boundary: SnapshotLoader_

- [ ] 2.2 (P) Grid Consistency Validator
  - 全てのスナップショット間で `nx, ny, nz` が一致していることを検証するロジックの実装。
  - 不整合検出時に明示的なエラーメッセージを表示して中断する処理。
  - 異なる格子サイズのスナップショット混在時にエラーがスローされる。
  - _Requirements: 1.2_
  - _Boundary: SnapshotLoader_

- [ ] 3. Core POD Computation Engine
- [ ] 3.1 (P) SVD Solver Implementation
  - `solver.jl` の実装。スナップショット行列からの平均場計算および減算処理。
  - `LinearAlgebra.svd` を用いた特異値分解の実行。
  - `compute_svd` が平均場と特異値分解の結果（U, S）を正しく返す。
  - _Requirements: 2.1_
  - _Boundary: SVDSolver_

- [ ] 3.2 (P) RIC-based Truncation Logic
  - 累積寄与率（RIC）の計算と、しきい値（デフォルト0.999）に基づくモード数 `r` の自動選定。
  - 指定された `ric_threshold` に応じて保持する基底ベクトルを切り出す処理。
  - 選定されたモード数がメタデータとして保持される。
  - _Requirements: 2.2, 2.3_
  - _Boundary: SVDSolver_

- [ ] 4. Integration and Result Persistence
- [ ] 4.1 POD Projection and Model Storage
  - 抽出された基底 $U_r$ への射影による POD 係数 $A = U_r^T X$ の算出。
  - `data/models/pod_model.jld2` への一括保存処理の実装。
  - `snapshot_ids`, `mu_vectors`, `trained_snapshot_ids`, および格子メタデータが正しく保存されること。
  - 実行完了後に `pod_model.jld2` が生成され、期待されるデータが全て含まれている。
  - _Requirements: 3.1, 4.1, 4.2_
  - _Depends: 2.1, 3.1_

- [ ] 5. Validation and Verification
- [ ] 5.1 (P) Unit Testing for PODEngine
  - 合成データ（直交基底から生成した行列）を用いた基底抽出の精度検証。
  - 各コンポーネント（Loader, Solver）の単体テスト。
  - `julia test/test_pod_engine.jl` ですべてのテストがパスする。
  - _Requirements: 1.1, 2.1_

- [ ] 5.2 Integration Test with Real Snapshots
  - `data/raw/` 配下の実際のスナップショットを用いたエンドツーエンドの実行テスト。
  - 物理的に妥当な平均温度場および特異値分布が得られるかの確認。
  - 実際のスナップショット群から次数低減モデルファイルが正常に作成される。
  - _Requirements: 1.1, 4.1_
