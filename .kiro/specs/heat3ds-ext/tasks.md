# Implementation Tasks: heat3ds-ext

## 基礎構築とインターフェース拡張
- [ ] Task 1.1: `heat3ds.jl` の `q3d` 関数の引数に `mu::Vector{Float64}=Float64[]` を追加する。
  - _Boundary:_ `H2-main-ext/src/heat3ds.jl`
- [ ] Task 1.2: `q3d` 関数内で `snapshot_path` が指定されている場合に `mu` も保存対象となるようデータフローを確認する。

## JLD2保存ロジックの実装
- [ ] Task 2.1: 計算終了後、`snapshot_path` が空でない場合に `JLD2.save` を実行するブロックを実装または更新する。
  - _Boundary:_ `H2-main-ext/src/heat3ds.jl`
  - _Requirement:_ 1.1, 1.2, 1.3
- [ ] Task 2.2: 保存データに `theta`, `mu`, `id_map`, および物理メタデータ（lx, ly, lz, grid）を含める。
- [ ] Task 2.3: `JLD2.save` を `try-catch` で囲み、書き込み失敗時もシミュレーションを継続できるようにする。
  - _Requirement:_ 3.2

## 既存機能との統合と検証
- [ ] Task 3.1: 保存処理が既存の可視化プロット（XZ, XY断面等）の実行に影響を与えないことを確認する。
  - _Requirement:_ 3.1
- [ ] Task 3.2: 単体実行テスト: `q3d` を直接呼び出し、ダミーの `mu` と `snapshot_path` を渡してファイルが正しく生成されるか確認する。
- [ ] Task 3.3: 既存の `snapshot_path` 未指定時の動作が変わらないことを確認する。
  - _Requirement:_ 2.2
