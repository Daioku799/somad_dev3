# 修正方針：ConfigLoader のエラー解消と密度マップ読み込み実装

## 課題
`ConfigLoader/Types.jl` に新規フィールドが追加されたのに対し、`ConfigLoader/Main.jl` の `load_config` 内でのインスタンス生成コードが古い引数のままであるため、実行時に `MethodError` が発生してソルバーの起動がクラッシュする。また、`tsv_mode="density"` 時の設定読み込みおよび制約のバリデーション処理が未実装である。

## 修正方針
1. **`load_config` の引数拡張とインスタンス化の修正**
   `config.json` および `tsv_config.json` から以下のフィールドをパースし、`TSVConfig` および `ModelConfig` を正しい引数で初期化する。

2. **密度マップ関連パラメータのパース**
   `tsv_config.json` に `density_map` セクションが存在する場合、`DensityMapConfig` を構築する。
   - `gx`, `gy`: グリッド分割数
   - `mu`: 密度ベクトル
   - `n_min`, `n_max`: 総TSV本数制約
   - `rho_cell_max`: セル密度上限
   - `prohibited_cells`: 配置禁止セル（座標のタプル配列 `Vector{Tuple{Int, Int}}` へ変換）

3. **製造制約およびGAパラメータのパース**
   - `manufacturing`: `ManufacturingConfig` を構築
   - `ga_settings`: `GASettings` を構築

4. **追加のシミュレーション環境パラメータのパース**
   `config.json` から以下のパラメータをロードし、`ModelConfig` に設定する（デフォルト値も適用）。
   - `snapshot_enabled`
   - `snapshot_dir`
   - `fixed_silicon_lambda`
   - `epsilon`
   - `max_iter`

5. **バリデーションロジックの追加**
   - `tsv_mode="density"` の場合、`mu` の要素数が `gx * gy` と一致することを検証。
   - 禁止セル (`prohibited_cells`) のインデックスがグリッド範囲内にあることを検証。

## 期待される成果
- `MethodError` によるクラッシュが解消し、FVMソルバーが起動できるようになる。
- 密度マップ構成情報が `tsv.density` に正しくロードされ、後続モジュールで参照可能になる。
