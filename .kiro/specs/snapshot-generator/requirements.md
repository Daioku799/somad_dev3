# Requirements Document

## Introduction
熱解析シミュレーションにおいて、ROM（次数低減モデル）構築のために必要なスナップショットデータを自動生成する機能を定義する。本機能は、密度マップ（Density Map）形式のパラメータ空間をサンプリングし、実TSV座標への展開を経てFVMソルバーを一括実行し、結果を永続化する。

## Boundary Context
- **In scope**: 
  - 密度マップベクトル `mu` のLHS（ラテン超格子サンプリング）生成。
  - `component-generator` を利用した実TSV座標への展開。
  - FVMソルバー（heat3ds.jl）の並列/連続実行プロセスの管理。
  - スナップショット（温度場データおよび対応するパラメータ）の JLD2 形式での保存。
  - 実行状態およびパラメータを管理する `manifest.json` の更新。
- **Out of scope**: 
  - FVMソルバー内部の熱伝導計算アルゴリズムの変更。
  - ROM基底の抽出（pod-engineが担当）。
  - GDSIIファイル自体の生成。
- **Adjacent expectations**: 
  - `config-loader` は `tsv_mode="density"` および密度制約を正しくパースできること。
  - `component-generator` は与えられた密度ベクトルから、TSV干渉のない実座標を生成できること。
  - `heat3ds-ext` はシミュレーション結果を構造化データとして返却または保存可能なインターフェースを提供すること。

## Requirements

### Requirement 1: 密度マップベースのパラメータサンプリング
**Objective:** As a 研究員, I want 密度マップ形式でパラメータ空間を効率的にサンプリングしたい, so that 少ない試行回数でROM構築に必要な情報を網羅できる

#### Acceptance Criteria
1. When サンプリングが開始される, the snapshot-generator shall Latin Hypercube Sampling (LHS) を用いて密度ベクトル `mu` の集合を生成する
2. The snapshot-generator shall `component-generator` の 「Constraint Adjustment」ユーティリティを使用して、各セルの密度 `mu_i` が設定された `max_density` および総TSV本数制約 $N_{limit}$ を遵守するようにサンプリング結果を調整する
3. While サンプリング実行中, the snapshot-generator shall 重複したパラメータセットが生成されないことを保証する

### Requirement 2: シミュレーション・オーケストレーション
**Objective:** As a 研究員, I want 大量のシミュレーションを自動で一括実行したい, so that 手動作業の手間を省き、計算機リソースを有効活用できる

#### Acceptance Criteria
1. When サンプリングされたパラメータセットが渡される, the snapshot-generator shall 「Constraint Adjustment」適用後の密度ベクトル `mu` を用いて、`component-generator` を呼び出し実TSV座標を算出する
2. The snapshot-generator shall Juliaのマルチスレッド機能またはプロセス並列を用いて、FVMソルバーを並列実行する
3. The snapshot-generator shall 同時実行プロセス数をシステムリソース（CPUコア数、メモリ）に基づき制限可能である

### Requirement 3: スナップショットデータの自動蓄積
**Objective:** As a 研究員, I want シミュレーション結果とパラメータを紐付けて自動保存したい, so that 後続のROM構築フェーズで即座にデータを利用できる

#### Acceptance Criteria
1. When シミュレーションが正常終了する, the snapshot-generator shall 温度場データ（3D配列）と「Constraint Adjustment」適用後の密度ベクトル `mu` を `data/raw/` ディレクトリに JLD2 形式で保存する
2. The snapshot-generator shall JLD2 メタデータ内に、ユニークなスナップショットIDを付与して保存する
3. The snapshot-generator shall 実行完了したケースのパラメータ（調整後 `mu`）とファイルパスを `data/manifest.json` に追記し、メタデータを更新する

### Requirement 4: エラーハンドリングと実行管理
**Objective:** As a 研究員, I want 一部のシミュレーションが失敗しても全体の実行を継続したい, so that 長時間の計算ジョブが途中で完全に停止するのを防ぎたい

#### Acceptance Criteria
1. If 特定のシミュレーション実行がタイムアウト（設定された最大時間を超過）した場合, then the snapshot-generator shall 当該プロセスを強制終了し、エラー内容をログに記録して次のケースに進む
2. If ソルバーが異常終了（収束失敗等）した場合, then the snapshot-generator shall 異常終了したパラメータセットを特定可能にし、`manifest.json` に失敗ステータスを記録する
3. The snapshot-generator shall 実行済みのケースをスキップし、中断された場所から再開する機能（レジューム機能）を提供する
