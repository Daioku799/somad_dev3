# Project Structure

## Organization Philosophy

**機能分離型のモジュラー構造**
責任範囲を「データロード」「幾何判定」「モデル構築」「視覚化」に明確に分離し、各モジュールを独立してテスト・検証可能な設計とする。

## Directory Patterns

### Core Source
**Location**: `src/`  
**Purpose**: プログラムの主要ロジック。機能ごとにサブディレクトリを持つ。  
**Example**: `src/ConfigLoader/`, `src/GdsMapping/`, `src/GeometryLogic/`, `src/ComponentGenerator/`, `src/ModelBuilder/`, `src/ValidationPlot/`


### Test Suite
**Location**: `test/`  
**Purpose**: 各モジュールのユニットテストおよび統合テストスクリプト。  
**Example**: `test/run_all.jl`

### Reference (Legacy/Original)
**Location**: `H2-main-original/`  
**Purpose**: 開発の基盤となるオリジナルコード。参照専用。

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
