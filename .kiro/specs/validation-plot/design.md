# Technical Design: validation-plot

## 1. System Architecture & Component Design

### 1.1 ValidationPlot モジュール
モデルと解析結果の視覚化を担う。

- `plot_model_structure(model_data, config) -> nothing`: 素材分布の各断面図と GDS 重ね合わせ図を生成。
- `plot_thermal_results(model_data, temperature_map, config) -> nothing`: 温度分布図の生成。

### 1.2 設定データの定義 (plots セクション)
`config.json` に以下を追加：
```json
"plots": {
    "output_dir": "plots",
    "xy_slices": [0.15, 0.195, 0.3, 0.345],
    "yz_slices": [0.6],
    "gds_overlay": true
}
```

## 2. Architecture Decisions & Integration

### 2.1 描画レイヤーの構築 (Traceability: 3.1, 3.2)
1. **Base Layer**: `heatmap` を使用して ID マップの断面を描画。物理座標（mm）を軸に設定。
2. **GDS Layer**: `config.plots.gds_overlay` が true の場合、`GdsMapping` から取得したポリゴンを `plot!` で重ね書き。
3. **Decoration**: 凡例（Legend）、タイトル、軸ラベル（Position [mm]）を付与。

### 2.2 温度分布の可視化 (Traceability: 2.2)
- 連続値（Float64）データに対し、`thermal` カラーマップを用いた `contourf` または `heatmap` を生成。
- 材料境界（IDマップから抽出）を薄く重ねることで、物理構造と温度の関係を明示する。

### 2.3 物理スケーリング (Traceability: 1.2)
- X, Y 方向: `1.2mm` 固定範囲。
- Z 方向: `model_data.coords.Z` 配列を使用。
- `aspect_ratio=:equal` を強制し、幾何学的な歪みを排除。

## 3. Boundary Commitments
- **Owned**: プロット生成ロジック、画像保存、カラーパレット、断面抽出。
- **Not Owned**: 解析ソルバーの実行、GDSII ファイルの直接パース。

## 4. File Structure Plan
- `src/ValidationPlot/ValidationPlot.jl`: 公開API。
- `src/ValidationPlot/Renderers.jl`: `Plots.jl` を用いた描画コア。
- `src/ValidationPlot/Slicer.jl`: 3Dデータからの断面抽出ユーティリティ。

## 5. Testing Strategy
- **Visual Tests**:
  - 生成された画像を目視で確認（TSVがチップ内に収まっているか、バンプが境界に接しているか）。
- **Unit Tests**:
  - `Slicer` が物理座標から正しいインデックスを返すか。
  - 出力ディレクトリが自動生成されるか。
