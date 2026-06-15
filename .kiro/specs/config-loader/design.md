# Technical Design: config-loader

## 1. System Architecture & Component Design

### 1.1 ConfigLoader モジュール
設定の読み込みと提供を担当する中心的なモジュール。

- `load_config(config_path, tsv_config_path)`: JSONをパースし、必須項目が欠落していればエラーを投げる。
- `generate_test_config()`: `H2-main-original` の値をベースにした `ModelConfig` オブジェクトを生成する。
- `calculate_z_markers(layers, pg_dpth)`: 層の厚みから zm0~zm12 を動的に算出する。

### 1.2 データ構造 (Types) (Traceability: 2.2, 1.4, 5.1-5.5)
- `Material`: `id::Int`, `name::String`, `lambda::Float64`, `rho::Float64`, `cp::Float64`
- `Layer`: `name::String`, `thickness::Float64`, `divisions::Int`, `grading::Float64`
- `DensityMapConfig`:
    - `gx::Int`, `gy::Int`: グリッド分割数 (5.1)
    - `mu::Vector{Float64}`: 密度ベクトル
    - `n_min::Int`, `n_max::Int`: 総TSV本数制約 (5.2)
    - `rho_cell_max::Float64`: セル密度上限 (5.2)
    - `prohibited_cells::Vector{Tuple{Int, Int}}`: 配置禁止セル (5.3)
- `ManufacturingConfig`:
    - `d_tsv::Float64`, `p_min::Float64`, `ar_min::Float64`, `ar_max::Float64`: 製造制約 (5.4)
- `GASettings`:
    - `n_pop::Int`, `n_gen::Int`, `cx_rate::Float64`, `mut_rate::Float64`: GAパラメータ (5.5)
- `TSVConfig`:
    - `mode::Symbol`: `:manual`, `:random`, `:density` (4.1)
    - `coords::Vector{Tuple{Float64, Float64}}`: 手動座標
    - `radius::Float64`, `height::Float64`: 基本寸法
    - `density::Union{Nothing, DensityMapConfig}`: 密度マップ詳細
    - `manufacturing::Union{Nothing, ManufacturingConfig}`: 製造制約
    - `ga::Union{Nothing, GASettings}`: GA設定
- `ModelConfig`:
    - `materials`, `layers`, `tsv`
    - `lx`, `ly`, `pg_dpth`, `s_dpth`, `d_ufill`, `r_bump`
    - `snapshot_enabled::Bool`, `snapshot_dir::String`: 保存設定 (6.1)
    - `fixed_silicon_lambda::Union{Nothing, Float64}`: 検証用物性 (6.2)
    - `epsilon::Float64`, `max_iter::Int`: ソルバー条件 (6.3)

## 2. Architecture Decisions & Integration

### 2.1 厳格なバリデーション (Traceability: 1.2, 5.3)
- JSONパース後、必須フィールドの存在をチェック。
- `tsv_mode="density"` の場合、`mu` の要素数が $gx \times gy$ と一致することを検証。
- 禁止セルの密度が 0 であることを検証。

### 2.2 Z座標計算アルゴリズム (Traceability: 3.1, 3.2)
- `layers` 定義（9層分）の累積合計から `zm0~zm12` を算出。
- シリコン層の終端から `pg_dpth` を差し引き、PowerGrid用のマーカーを配置。
- 浮動小数点誤差を排除するため、最終結果を 15 桁で丸める。

### 2.3 密度マップの統合 (Traceability: 1.4, 4.1, 5.1-5.5)
- `tsv_config.json` に新設される `density_map`, `manufacturing`, `ga_settings` セクションを読み込む。
- モードが `density` でない場合でも、製造制約などの共通項目は読み込み可能とする。

## 3. Boundary Commitments
- **Owned**: 設定JSONのパース、不変構造体へのマッピング、累積Z座標計算、制約条件の検証。
- **Not Owned**: 密度マップから実座標への展開ロジック（`component-generator` が担当）。

## 4. File Structure Plan
- `src/ConfigLoader/ConfigLoader.jl`: 公開APIとモジュール定義。
- `src/ConfigLoader/Types.jl`: 構造体定義（DensityMapConfig等を含む）。
- `src/ConfigLoader/Defaults.jl`: `H2-main-original` 由来の定数定義。
- `src/ConfigLoader/Calculators.jl`: Z座標およびはんだ半径の計算ロジック。
- `src/ConfigLoader/Main.jl`: JSON読み込みとバリデーションのメインロジック。

## 5. Testing Strategy
- **Unit Tests**:
  - `tsv_mode="density"` 時の必須パラメータ（gx, gy, mu）読み込みテスト。
  - `mu` のサイズ不整合時のエラー発生テスト。
  - Z座標計算結果の再現性検証（オリジナル定数との比較）。
  - 禁止セル制約のバリデーションテスト。
- **Integration Tests**:
  - `ModelConfig` が `component-generator` などの下流モジュールで正しく参照できるかの確認。
