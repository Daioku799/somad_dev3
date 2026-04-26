# Implementation Tasks: snapshot-generator

## 1. 基盤：実行環境とマニフェスト管理
- [ ] 1.1 ディレクトリ構造とワークスペースの初期化
  - `data/raw/` および `data/work/` ディレクトリをプロジェクトルートに作成する
  - `.gitignore` を更新し、`data/work/` 以下の作業ファイルを追跡対象外にする
  - `data/` ディレクトリが存在し、適切な書き込み権限があることが確認できる
  - _Requirements: 4.1_

- [ ] 1.2 マニフェスト・レジストリとメタデータ管理の実装
  - `src/SnapshotGenerator/Manifest.jl` を作成し、`manifest.json` の構造定義と I/O 機能を実装する
  - ケースの追加、ステータス更新（success/failed/timeout）、および一括保存機能を実装する
  - プロジェクトルートに有効な `manifest.json` が生成され、`JSON3` で読み書きできる
  - _Requirements: 3.3_

## 2. ソルバー拡張：H2-main-ext のスナップショット対応
- [ ] 2.1 heat3ds.jl のデータ抽出と永続化対応
  - `H2-main-ext/src/heat3ds.jl` の `q3d` 関数を修正し、`snapshot_path` 引数を受け取れるようにする
  - シミュレーション完了時に温度場 $\theta$、物理パラメータ、グリッド情報を `JLD2` 形式で保存するロジックを追加する
  - ソルバー実行後に指定したパスに `.jld2` ファイルが生成され、内部の `theta` 配列が正しい型であることを確認できる
  - _Requirements: 3.1, 3.2_

- [ ] 2.2 run.jl へのコマンドラインオプションの追加
  - `H2-main-ext/run.jl` に `--snapshot` オプションを追加し、出力先パスを `q3d` に渡すよう修正する
  - `--snapshot` 指定時にログ出力（"Saving snapshot to..."）を行うようにする
  - コマンドラインから `--snapshot test.jld2` を指定して実行し、指定通りのファイルが生成される
  - _Requirements: 3.2_

## 3. パラメータサンプリング：LHSジェネレータ
- [ ] 3.1 (P) Latin Hypercube Sampling によるパラメータ生成の実装
  - `src/SnapshotGenerator/Sampler.jl` を作成し、`LatinHypercubeSampling.jl` を用いたサンプリングロジックを実装する
  - $r_{tsv}$, $N_{tsv}$, および $(x, y)$ 座標を指定された範囲内で生成可能にする
  - 指定したケース数の正規化済みおよび物理パラメータセットが正しく生成される
  - _Requirements: 1.1, 1.2_
  - _Boundary: SnapshotGenerator/Sampler_

- [ ] 3.2 (P) 物理制約バリデーション・カーネルの実装
  - 生成された TSV 配置がチップ境界内にあること、および TSV 間の最小距離を満たしていることを検証する関数を実装する
  - バリデーションに失敗したパラメータセットを棄却し、有効なセットが揃うまで再試行するロジックを追加する
  - 意図的に不正な配置を与えた際にエラーを検出し、有効な配置のみがサンプラーから返される
  - _Requirements: 1.3_
  - _Boundary: SnapshotGenerator/Sampler_

## 4. 実行オーケストレータ：バッチシミュレーション管理
- [ ] 4.1 ケース用ワークスペースの隔離と設定注入
  - `src/SnapshotGenerator/Runner.jl` を作成し、各ケースごとに `data/work/case_{id}/` を作成する機能を実装する
  - サンプリングされたパラメータに基づき、各ディレクトリに `config.json` を生成して配置する
  - 実行時に各ディレクトリに必要な `config.json` が存在し、内容がサンプリング結果と一致している
  - _Requirements: 2.2, 4.1_

- [ ] 4.2 タイムアウトとエラーリカバリを伴う一括実行制御
  - `H2-main-ext/run.jl` を外部プロセスとして呼び出し、個別の `timeout_sec` を監視する機能を実装する
  - ソルバーの失敗（非収束、実行時エラー）をキャッチし、ログを記録した上で次のケースへ進む制御ループを実装する
  - タイムアウトが発生したプロセスが確実に kill され、マニフェストに失敗状態が正しく記録される
  - _Requirements: 2.1, 2.3, 2.4_

## 5. 最終統合とレポート
- [ ] 5.1 エンドツーエンド実行とサマリーレポート
  - 全工程を統合したメインエントリを作成し、実行完了後に成功・失敗・スキップ数の集計レポートを表示する
  - 全ケース完了後、`data/raw/` にスナップショットが揃い、`manifest.json` が最終更新される
  - 標準出力に実行統計（成功率、平均実行時間等）が表示され、処理が正常に終了する
  - _Requirements: 4.2_
  - _Depends: 1.2, 4.2_
