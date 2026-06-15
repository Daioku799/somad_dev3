# Project Structure

## Organization Philosophy

**機能分離型のモジュラー構造**
責任範囲を「データロード」「幾何判定」「モデル構築」「視覚化」に明確に分離し、各モジュールを独立してテスト・検証可能な設計とする。また、物理ソルバー（FVM）と次数低減モデル（ROM）を別プロジェクトとして分離管理する。

## Project Layout

### FVM Solver Extension (`H2-main-ext/`)
**Purpose**: 既存の熱解析コードを拡張・整理した主要な物理ソルバー環境。
- `src/`: 機能ごとのサブディレクトリ（ConfigLoader, GdsMapping等）。
- `test/`: ユニットテスト。

### ROM Development (`H2-rom/`)
**Purpose**: 次数低減モデル（POD-RBF）の構築と検証。
- `src/`: スナップショット生成、基底抽出等のロジック。

### Shared Data (`data/`)
**Purpose**: プロジェクト全体で共有されるデータ。
- `raw/`: FVMから生成されたスナップショット（.jld2）。
- `models/`: 訓練済みのROMモデル。
- `plots/`: 検証用プロット画像。
- `work/`: 解析実行時のテンポラリディレクトリ。
- `manifest.json`: 全ケースのパラメータと実行状態の統合管理。

## Directory Patterns (Module Internal Structure)

各機能ディレクトリ（例: `src/ConfigLoader/`）は以下の構成を基本とする。

- `Types.jl`: データ構造（struct）の定義。
- `Main.jl`: 主要な手続きロジック。
- `Defaults.jl`: デフォルト値や定数（存在する場合）。
- `Calculators.jl`: 純粋な計算ロジック（存在する場合）。
- `{ModuleName}.jl`: 親ファイル。上記ファイルを `include` し、インターフェースをエクスポートする。

## Naming Conventions

- **Modules**: PascalCase (e.g., `ConfigLoader`)
- **Types**: PascalCase (e.g., `ModelConfig`)
- **Functions**: snake_case (e.g., `load_config`)
- **Variables**: snake_case (e.g., `z_markers`)
- **Files**: PascalCase (e.g., `Parser.jl`)

## Import Organization

```julia
# モジュール内でのサブモジュール読み込み
include("SubModule.jl")
using .SubModule
```

## Code Organization Principles

- **依存方向の管理**: 上流（Types, Defaults）から下流（Parser, Calculators）への一方向依存を維持する。
- **境界の明示**: 各ディレクトリには `_Boundary:_` を意識した責務を持たせる。

---
_Document patterns, not file trees. New files following patterns shouldn't require updates_
