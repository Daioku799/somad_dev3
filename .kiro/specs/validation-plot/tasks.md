# Implementation Tasks: validation-plot

- [ ] 1. Foundation: 共通パレットとスライサーの基盤整備
- [x] 1.1 材料ID用共通カラーパレットの定義
  - レガシーコード（H2-main_TSV_Opt）と互換性のある配色定数を定義する
  - `MATERIAL_LABELS` および `LEGACY_COLOR_PALETTE` を含む `Palettes.jl` を作成する
  - モデル構築時とスナップショット時の両方で利用可能な共通パレット定数がエクスポートされていること
  - _Requirements: 2.1, 3.2_

- [ ] 1.2 スライサーユーティリティの整理
  - 物理座標からインデックスへの変換および断面抽出ロジックを整理する
  - `Slicer.jl` の `get_xy_slice` 等が任意の3Dデータ（IDマップおよび温度場）に対応していることを確認する
  - 既存のモデル検証プロット（`plot_model_validation`）に影響を与えず、データ抽出が汎用的に動作すること
  - _Requirements: 1.2_

- [ ] 2. Core: スナップショット検証プロットの実装
- [ ] 2.1 (P) スナップショットデータの読み込みロジック
  - `JLD2.jl` を使用して指定されたスナップショットから `id_map`, `theta`, `z_centers` 等を抽出する
  - 非一様格子のZ座標情報を正しくパースする
  - `Snapshot.jl` 内にJLD2ファイルのキー構造に依存した抽出関数が実装されていること
  - _Requirements: 3.1_
  - _Boundary: Snapshot.jl_

- [ ] 2.2 (P) サイドバイサイドプロットの描画エンジン
  - `Plots.jl` の `layout=(1, 2)` を使用して材料分布と温度分布を1画面に配置する
  - 材料分布側には `Palettes.jl` のレガシー配色を適用する
  - 温度分布側には引数で指定された `temp_lims` による固定スケールを適用する
  - `plot_snapshot_validation` 関数により、指定したディレクトリに画像が保存されること
  - _Requirements: 2.2, 2.3, 3.2, 4.1, 4.2_
  - _Boundary: Snapshot.jl_

- [ ] 3. Integration & Validation: モジュール統合と最終確認
- [ ] 3.1 モジュールエントリの更新と公開
  - `ValidationPlot.jl` で新設ファイルをインクルードし、エクスポート設定を行う
  - 既存のGDSオーバーレイロジックを整理（不要な依存の削除）する
  - 外部モジュールから `plot_snapshot_validation` が直接呼び出し可能であること
  - _Requirements: 4.2_

- [ ] 3.2 統合テストとスケール検証
  - 複数のスナップショットに対してプロットを実行し、温度スケール（カラーバー）が統一されていることを目視およびデータで確認する
  - 材料IDの色分けがレガシープロットの結果と一致することを検証する
  - `plots/` ディレクトリに正しい命名規則で統合プロット画像が生成されていること
  - _Requirements: 2.3, 3.2, 4.2_
