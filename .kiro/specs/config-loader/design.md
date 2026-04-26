# Technical Design: config-loader

## 1. System Architecture & Component Design

### 1.1 ConfigLoader モジュール
設定の読み込みと提供を担当する中心的なモジュール。

- `load_config(config_path, tsv_config_path)`: JSONをパースし、必須項目が欠落していればエラーを投げる。
- `generate_test_config()`: `H2-main-original` の値をベースにした `ModelConfig` オブジェクトを生成する。
- `calculate_z_markers(layers, pg_dpth)`: 層の厚みから zm0~zm12 を動的に算出する。

### 1.2 環境セットアップ (Traceability: 2.1)
- `Project.toml` を利用したパッケージ管理を行い、`JSON.jl`, `SimpleGDS.jl` などの依存関係を固定する。
- 実行時に `Pkg.activate(".")` および `Pkg.instantiate()` を呼び出し、再現可能な実行環境を構築する。

### 1.3 データ構造 (Types) (Traceability: 2.2)
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
1. `layers` 配列（9層分）を順次走査。
2. zm0 = 0.0 を起点とし、各層の `thickness` を累積加算して zm1, zm2, zm4, zm5, zm7, zm8, zm10, zm11, zm12 を決定。
3. シリコン層（zm4, zm7, zm10）の終端から `pg_dpth` を差し引き、zm3, zm6, zm9 を算出。
4. この動的算出により、JSONで厚みを変更しても物理的な層構造の整合性を維持する。

### 2.4 Zcoord.jl との統合 (Traceability: 3.1)
- 算出された zm0~zm12 の定数群を `Zcoord.jl` モジュールに提供する。
- `Zcoord.jl` はこれらの定数を参照し、オリジナルの点配置アルゴリズム（Zcase2! 等）を実行して格子を生成する。

## 3. Boundary Commitments
- **Owned**: 設定ファイルのパース、材料データ構造、累積Z座標計算ロジック、試験用データ生成、Julia環境初期化。
- **Not Owned**: 解析実行時の自動的なデフォルト補完。

## 4. File Structure Plan
- `src/ConfigLoader/ConfigLoader.jl`: 公開APIと読み込みメインロジック。
- `src/ConfigLoader/Types.jl`: 構造体定義。
- `src/ConfigLoader/Defaults.jl`: `H2-main-original` 由来の定数定義（試験用）。
- `Project.toml`: 環境定義。

## 5. Testing Strategy
- **Unit Tests**:
  - 必須項目が欠落したJSONを読み込んだ際に正しくエラーになるか。
  - `generate_test_config` がオリジナルの数値と一致するオブジェクトを生成するか。
  - Z座標の計算結果（特にオフセットを含む `zm3, 6, 9`）の正確性。
