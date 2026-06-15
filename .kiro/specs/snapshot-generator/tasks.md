# Implementation Tasks: snapshot-generator

## 基盤構築とマニフェスト管理
- [ ] Task 1.1: `Types.jl` にマニフェスト（`SnapshotManifest`, `SnapshotCase`）の構造体を定義する。
  - _Boundary:_ `H2-rom/src/SnapshotGenerator/Types.jl`
- [ ] Task 1.2: `Manifest.jl` に `manifest.json` のロード・セーブ・更新ロジックを実装する。
  - _Boundary:_ `H2-rom/src/SnapshotGenerator/Manifest.jl`

## パラメータサンプリング
- [ ] Task 2.1: `Sampler.jl` に `LatinHypercubeSampling.jl` を用いた密度マップサンプリングを実装する。
  - _Boundary:_ `H2-rom/src/SnapshotGenerator/Sampler.jl`
- [ ] Task 2.2: `ComponentGenerator.Layout.adjust_density_constraints` を使用して、サンプリングされた `mu` が物理制約を遵守するように調整する。
- [ ] Task 2.3: 代表パターン（均一密度、中央集中等）を初期サンプルとして生成する機能を追加する。
  - _Requirement:_ 1.2

## ソルバー実行・オーケストレーション
- [ ] Task 3.1: `Runner.jl` にシミュレーションケースごとの作業ディレクトリ作成ロジックを実装する。
  - _Boundary:_ `H2-rom/src/SnapshotGenerator/Runner.jl`
- [ ] Task 3.2: 調整済み `mu` を用いて `component-generator` を呼び出し、実座標へ展開して `tsv_config.json` を動的生成する。
  - _Requirement:_ 2.2, 2.3
- [ ] Task 3.3: ソルバーの外部プロセス起動とタイムアウト・エラーハンドリングを実装する。
  - _Requirement:_ 2.4, 2.5
- [ ] Task 3.4: 解析結果を JLD2 に保存する際、メタデータとしてユニークなスナップショットIDと調整済み `mu` を含める。また、成功した結果を `data/raw/` へ移動しマニフェストを更新する。

## 統合と検証
- [ ] Task 4.1: `SnapshotGenerator.jl` エントリポイントを実装し、一連のフローを統合する。
- [ ] Task 4.2: ユニットテスト: Sampler の分布と制約遵守を検証する。
- [ ] Task 4.3: E2Eテスト: 少数のサンプルで `mu -> 展開 -> FVM -> JLD2保存 -> Manifest更新` が完走することを確認する。
