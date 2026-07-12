# Implementation Plan: ga-optimizer

## Tasks

- [ ] 1. Foundation: 型定義と最適化設定の構築
- [x] 1.1 最適化エンジンで使用するデータ構造の定義
  - 密度マップ `mu`、個体（Individual）、および最適化状態（OptimizationState）の構造体を `Types.jl` に定義
  - 適合度（fitness）や検証ステータスを管理するフィールドの追加
  - 型安全性が確保されたデータ構造が `H2-rom/src/GaOptimizer/Types.jl` に作成されていること
  - _Requirements: 1.1_
- [ ] 1.2 最適化パラメータのロード機能の拡張
  - `config-loader` を介して、GAパラメータ（世代数、個体群サイズ、突然変異率、エリート数等）をJSONからロード
  - `OptimizationConfig` 構造体にパラメータが正しくマッピングされること
  - _Requirements: 1.4_

- [ ] 2. Constraint Management: 密度マップ制約修正エンジンの実装
- [ ] 2.1 (P) 密度マップの正規化と境界チェックの実装
  - ベクトル `mu` の総和が総TSV本数上限を超えないよう比例スケーリングする関数の作成
  - 各要素 `mu_i` が [0.0, 1.0] の範囲に収まるようクランプ処理を実装
  - テストコードにより、制約違反の個体が有効な範囲に修正されることが確認されていること
  - _Requirements: 2.1, 2.2_
  - _Boundary: ConstraintManager_
- [ ] 2.2 (P) 配置禁止領域とセル密度上限の強制適用
  - `forbidden_zones`（配置禁止エリア）に該当するセルの密度を 0 に固定するロジックの実装
  - セルごとの最大密度制約（max_density_per_cell）の適用
  - _Requirements: 2.1_
  - _Boundary: ConstraintManager_
- [ ] 2.3 (P) 無効な個体の検知と再生成プロセスの実装
  - 修正後の個体が極端に無効（全要素が0など）な場合に、有効な個体が得られるまで再サンプリングを行う仕組み
  - 異常な個体が GA ループに混入せず、常に制約を満たす個体群が維持されること
  - _Requirements: 2.3_
  - _Boundary: ConstraintManager_

- [ ] 3. GA Engine: 最適化ループの構築
- [ ] 3.1 (P) 密度マップ用遺伝的オペレータの実装
  - ベクトル表現に適した交叉（ブレンド交叉等）および突然変異（ガウス突然変異等）の実装
  - 操作の直後に `ConstraintManager` を自動呼び出し、常に制約を維持する仕組み
  - _Requirements: 1.3, 2.2_
  - _Boundary: Engine_
- [ ] 3.2 (P) 適合度評価と選択ロジックの実装
  - ROMインターフェースを用いた予測最高温度の取得と適合度計算の実装
  - トーナメント選択等のアルゴリズムによる次世代個体群の選定フロー
  - _Requirements: 1.1, 1.2_
  - _Boundary: Engine_

- [ ] 4. Reliability & FVM: 信頼性管理と再検証の実装
- [ ] 4.1 (P) ROMの外挿検知ロジックの実装
  - `ROMInterpolator.is_reliable(model, mu)` API を使用した、入力 `mu` が訓練データの範囲内にあるかの判定
  - 外挿と判定された個体に対してログを記録し、信頼性スコアを付与する機能
  - _Requirements: 3.1_
  - _Boundary: ReliabilityManager_
- [ ] 4.2 (P) 有望個体（エリート）に対するFVM自動再検証
  - 最適化プロセス中の上位個体に対して `solve_thermal(mu)` API を直接呼び出して解析を実行
  - FVMソルバーを実行し、ROM予測値と実際の解析結果の誤差を記録
  - _Requirements: 3.2, 3.3_
  - _Boundary: ReliabilityManager_

- [ ] 5. Integration & Final Validation: システム統合と最終検証フロー
- [ ] 5.1 最適化メインエントリの実装と実行制御
  - `GaOptimizer.jl` における全コンポーネントの統合と `run_optimization` 関数のエクスポート
  - 中間結果の永続化（JLD2）と、世代ごとの進捗（収束曲線）のコンソール出力
  - _Requirements: 1.4_
- [ ] 5.2 最終解の物理モデル生成と検証フローの完遂
  - 最適化完了後、最良個体に対して `solve_thermal(mu)` API を呼び出し、最終検証を必須で実行
  - 解析結果、実配置座標データ、ROM/FVM比較を含む最終サマリレポートの生成
  - _Requirements: 4.1, 4.2, 4.3_
