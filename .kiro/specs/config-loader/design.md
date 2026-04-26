# Technical Design: config-loader

## 1. System Architecture & Component Design

### 1.1 ConfigLoader モジュール
設定の読み込みと提供を担当する中心的なモジュール。

- `load_config(config_path, tsv_config_path)`: JSONをパースし、必須項目が欠落していればエラーを投げる。
- `generate_test_config()`: `H2-main-original` の値をベースにした `ModelConfig` オブジェクトを生成する。

### 1.2 データ構造 (Types)
- `Material`: `id::Int`, `name::String`, `lambda::Float64`, `rho::Float64`, `cp::Float64`
- `Layer`: `name::String`, `thickness::Float64`, `divisions::Int`, `grading::Float64`
- `TSVConfig`: `mode::Symbol`, `coords::Vector{Tuple{Float64, Float64}}`, `radius::Float64`, `height::Float64`
- `ModelConfig`: 全ての `Material`, `Layer`, `TSVConfig`, および基本寸法を含む。

## 2. Architecture Decisions & Integration

### 2.1 厳格なバリデーション (Traceability: 1.2)
JSONパース後、全ての必須フィールドが存在するかをチェックする。`nothing` を許容せず、欠落があれば `ArgumentError` を発生させる。

### 2.2 試験用初期値の提供 (Traceability: 1.3)
`DefaultValues` モジュールに `H2-main-original` の定数を定義し、`generate_test_config` 関数内でこれらを用いて `ModelConfig` を構築する。

### 2.3 Z座標計算アルゴリズム (Traceability: 3.1, 3.2)
1. `layers` 配列を走査。
2. 厚みを累積加算し `z_markers` 配列（長さ13）を作成。
3. `Silicon` 層の終端座標から `pg_dpth` を引いた値を PGマーカーとして算出。

## 3. Boundary Commitments
- **Owned**: 設定ファイルのパース、材料データ構造、累積Z座標計算ロジック、試験用データ生成。
- **Not Owned**: 解析実行時の自動的なデフォルト補完。

## 4. File Structure Plan
- `src/ConfigLoader/ConfigLoader.jl`: 公開APIと読み込みメインロジック。
- `src/ConfigLoader/Types.jl`: 構造体定義。
- `src/ConfigLoader/Defaults.jl`: `H2-main-original` 由来の定数定義（試験用）。

## 5. Testing Strategy
- **Unit Tests**:
  - 必須項目が欠落したJSONを読み込んだ際に正しくエラーになるか。
  - `generate_test_config` がオリジナルの数値と一致するオブジェクトを生成するか。
  - Z座標の計算結果（特にオフセットを含む `zm3, 6, 9`）の正確性。
