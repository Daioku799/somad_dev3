# Requirements: validation-plot

## 1. 設定駆動型のプロット生成
- 1.1 **[JSON指定のスライス]** When `config.json` で断面座標（X, Y, Z）および注目レイヤーが指定されたとき, the Validation Plot module shall 自動的にプロットを生成しなければならない。
- 1.2 **[物理スケーリング]** The Validation Plot module shall 全てのプロットにおいて、座標軸に実際の物理寸法（mm）を反映しなければならない。

## 2. 可視化対象の拡大
- 2.1 **[材料分布プロット]** When 材料IDデータが提供されたとき, the Validation Plot module shall 各IDに識別しやすい色を割り当てた2D断面図を生成しなければならない。
- 2.2 **[温度分布プロット]** When 解析ソルバーから温度データが出力されたとき, the Validation Plot module shall 等高線図またはヒートマップを生成しなければならない。
- 2.3 **[温度スケールの統一]** The Validation Plot module shall 全ての温度場プロットにおいて、比較を容易にするため統一された温度スケール（カラーバー範囲）を使用しなければならない。

## 3. スナップショット検証
- 3.1 **[スナップショットファイルの読み込み]** When JLD2形式のスナップショットファイルが提供されたとき, the Validation Plot module shall 内部の `id_map` および `theta` データを抽出してプロットに使用できなければならない。
- 3.2 **[TSV検証用プロットの再現]** When TSV検証用プロットが要求されたとき, the Validation Plot module shall レガシーな `geo_overlay_` 形式（例：ID 1:Orange, ID 7:Red）に準拠した配色でXY断面図を生成しなければならない。

## 4. 統合表示とデータ管理
- 4.1 **[サイドバイサイド表示]** When スナップショットの検証プロットが実行されるとき, the Validation Plot module shall 「材料IDマップ」と「温度場プロット」を1つの画像内で横並びに表示しなければならない。
- 4.2 **[画像エクスポート]** When プロットが生成されたとき, the Validation Plot module shall パラメータ情報を付随させたファイル名で、指定ディレクトリ（例：`plots/`）に画像を保存しなければならない。

## Scope Boundaries
- **In**: 設定ファイルまたはスナップショットファイルに基づく断面抽出、ID/温度プロット（横並び表示、統一温度スケール含む）、レガシー互換配色。
- **Out**: GDS境界線のオーバーレイ描画、リアルタイム 3D プレビュー、対話型 GUI による操作。
