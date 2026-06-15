# Requirements: heat3ds-ext

## Project Description (Input)
オリジナルのFVMソルバー（`heat3ds.jl`）は、計算結果をテキストログやCSV、画像として出力するが、ROM構築用のバイナリ形式（JLD2）での温度場保存に対応していない。計算終了後、収束した温度場（3次元配列 $\theta$）および入力パラメータ `mu` を JLD2 形式でファイル保存する機能を `heat3ds.jl` またはその周辺に追加する。

## 1. JLD2スナップショットの生成
- 1.1 When シミュレーションが収束したとき、 The Solver shall 収束した3次元温度場（$\theta$）をJLD2バイナリ形式で保存すること。
- 1.2 The Solver shall 保存されるJLD2ファイルに、元の3次元次元（例：$NX+2, NY+2, NZ+3$）を維持した温度配列を含めること。
- 1.3 The Solver shall データ追跡性を確保するため、保存されるJLD2ファイルにシミュレーションで使用されたTSV密度マップベクトル（`mu`）を含めること。

## 2. 出力設定と制御
- 2.1 The Solver shall コマンドライン引数または設定JSONを通じて、JLD2スナップショットの保存先パスを指定できる機能を提供すること。
- 2.2 Where JLD2の保存先パスが指定されていない場合、 The Solver shall バイナリ保存をスキップして通常の処理を継続すること。

## 3. 非機能要件と互換性
- 3.1 The Solver shall JLD2保存機能の追加によって、既存のテキスト、CSV、画像出力プロセスを妨げないこと。
- 3.2 If JLD2ファイルの書き込みに失敗した場合、 The Solver shall エラーを報告し、シミュレーション全体を異常終了させずに処理を継続すること。

## Scope Boundaries
- **In**: 温度場 $\theta$ および密度マップ `mu` の JLD2 シリアライズ、保存パスのインターフェース、基本的な書き込みエラーハンドリング。
- **Out**: 温度場の可視化（`plotter.jl`が担当）、スナップショットのディレクトリ管理や履歴管理（`snapshot-generator`が担当）。
