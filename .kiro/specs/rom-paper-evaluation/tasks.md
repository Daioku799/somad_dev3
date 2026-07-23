# Implementation Plan

- [ ] 1. Foundation: 評価モジュールの雛形作成
- [x] 1.1 PaperEvaluation モジュールの骨組みとデータサイズモニター関数の実装
  - `H2-rom/src/PaperEvaluation/` ディレクトリを作成し、`PaperEvaluation.jl` ファイルを配置する
  - モジュール構造を定義し、基底行列 $U$ と RBF重み行列 $W$ の要素数およびメモリサイズを算出する `monitor_rom_size` 関数を実装する
  - テストスクリプトから `PaperEvaluation` モジュールが正常にロードでき、モデルサイズ計算関数が「要素数」と「バイトサイズ(KB/MB)」を含む正しい可読文字列を返すことを確認する
  - _Requirements: 1.1_
  - _Boundary: PaperEvaluation_

- [x] 1.2 ROM構築時間計測ヘルパーの実装
  - ROM構築および検証フェーズ全体の処理時間を計測し、秒単位で記録するヘルパー関数を `PaperEvaluation` モジュール内に実装する
  - ROM構築処理の終了時に、計測された構築時間がログおよび検証レポートにテキストで正しく出力されることを確認する
  - _Requirements: 1.4_
  - _Boundary: PaperEvaluation_

- [ ] 2. Core: 論文用可視化機能の実装
- [x] 2.1 SVD特異値減衰・RIC推移プロットの実装
  - `PaperEvaluation.plot_svd_decay` 関数を実装する
  - Plots.jl を使用し、特異値の減衰を対数軸で、累積寄与率（RIC）の推移を折れ線グラフで、同一のモード数（X軸）に対して描画する2軸プロットを作成する
  - スクリプト実行により、指定された出力パスに妥当な特異値減衰とRIC推移を示すグラフ画像（PNG形式）が正常に保存されることを確認する
  - _Requirements: 1.2_
  - _Boundary: PaperEvaluation_

- [x] 2.2 RBFパラメータスイープと誤差感度プロットの実装
  - `PaperEvaluation.sweep_rbf_parameters` 関数を実装する
  - パラメータ $\varepsilon$ (線形スケール) と $\lambda$ (対数スケール) の各組み合わせに対して RBF モデルを構築し、検証データに対する相対L2誤差およびTmax絶対誤差を算出するロジックを実装する
  - 誤差の感度を示す2次元ヒートマップ（L2用およびTmax用）プロットを生成する処理を実装する
  - スイープ処理を外部パラメータで調整可能にし、実行後に2枚のヒートマップ画像が指定ディレクトリに保存されることを確認する
  - _Requirements: 1.3_
  - _Boundary: PaperEvaluation_

- [ ] 3. Core: レガシー実行ラッパーの実装
- [x] 3.1 (P) レガシーFVMソルバー実行ラッパーの構築
  - `legacy/H2-main-original/legacy_run_wrapper.jl` を作成する
  - コマンドライン引数から一時IDマップファイル（JLD2形式）のパスを受け取り、ロードする
  - レガシーの `WorkBuffers` を作成し、ロードしたIDマップおよび対応する物性配列（$\lambda, \rho, cp$）、Z座標データを直接 WorkBuffers に注入する
  - 隔離プロセスでレガシーFVMソルバー（`main`）をシングルスレッド（`par="sequential"`）、収束判定閾値 `epsilon=1e-6` で実行し、得られた温度場データを一時ファイルに保存する
  - 本スクリプトを一時ファイルパスを指定して単体起動したとき、エラーなくレガシーFVMが動作し、期待される温度場データがJLD2として正常に出力されることを確認する
  - _Requirements: 2.1_
  - _Boundary: legacy_run_wrapper_

- [ ] 4. Core & Integration: 等価性検証機能の実装
- [ ] 4.1 新旧FVM等価性検証メインスクリプトの実装
  - `verify_legacy_fvm.jl` スクリプトを新規作成する
  - 現行の `build_model` を呼び出してIDマップおよび物性・座標データを構築し、現行のFVMソルバーを実行して温度場 `theta_new` を得る
  - 構築したIDマップ等を一時ファイルに保存し、外部プロセス（`julia`）を起動して `legacy_run_wrapper.jl` を実行させ、レガシーの温度場 `theta_legacy` を読み込む
  - 両者の最大絶対誤差を算出し、誤差が $10^{-12}$ K以下であることを `@assert` で自動検証するアサーション処理を実装する
  - 本スクリプトを実行したとき、アサーションが成功してプロセスが正常終了すること、また失敗時には最大誤差の値と発生座標がログに出力されることを確認する
  - _Requirements: 2.1, 2.2, 2.3_
  - _Boundary: verify_legacy_fvm_
  - _Depends: 3.1_

- [ ] 4.2 検証用プロット出力ロジックの実装
  - `verify_legacy_fvm.jl` 内に、新旧FVMの物理量を可視化するプロット関数を実装する
  - 新旧それぞれの材質プロット、温度場断面（XY, XZ）プロット、および新旧の温度場の差分（絶対誤差）を示すヒートマップを生成するロジックを記述する
  - 検証スクリプト実行完了時に、`plots/legacy_verification/` 配下に材質プロット、新旧温度比較プロット、温度差分ヒートマップの画像（PNG）が正しく出力されることを確認する
  - _Requirements: 2.4_
  - _Boundary: verify_legacy_fvm_

- [ ] 5. Integration & Validation: メインスクリプト構築と統合テスト
- [ ] 5.1 論文用ROM評価ワークフローの作成
  - ルートディレクトリに `evaluate_rom_paper.jl` スクリプトを新規作成する
  - `PaperEvaluation` モジュールをロードし、スナップショットデータに対してSVDプロット、RBFスイーププロット、ROMサイズおよび構築時間のモニター出力を統合実行するワークフローを定義する
  - スクリプトを実行した際、すべての論文用プロット画像が `plots/paper_evaluation/` に正常に出力され、ログテキストに構築時間とデータサイズ情報が記録されることを確認する
  - _Requirements: 1.1, 1.2, 1.3, 1.4_
  - _Boundary: evaluate_rom_paper_
  - _Depends: 1.1, 1.2, 2.1, 2.2_

- [ ] 5.2 統合テストスイートの構築
  - `test/` ディレクトリに本追加要件のテストケースを追加、または専用のテストスクリプトを作成する
  - `monitor_rom_size` および `verify_legacy_fvm.jl` の各機能に対するユニットテスト・統合テストを実装する
  - テストランナーを実行した際に、新規追加されたテストケースがすべてパスすることを確認する
  - _Requirements: 1.1, 1.2, 2.3_
  - _Boundary: Testing_
