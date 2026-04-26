# Research Log: config-loader

## Summary
`H2-main-original` の `modelA.jl` からハードコードされた定数を抽出し、それらをデフォルト値として外部設定ファイル（JSON）と統合する設計を調査した。Julia の構造体を用いることで、プログラム全体で型安全かつ不変な設定データを提供できることを確認した。

## Research Log Topics

### Topic 1: オリジナルのデフォルト値抽出
- **Source**: `H2-main-original/src/modelA.jl`
- **Findings**:
  - 寸法定数（`pg_dpth` 等）が `const` で定義されている。
  - 材料物性が `Dict` で管理されているが、これらは解析中に変化しないため `struct` への移行が適している。
  - Z座標マーカー（`zm0`〜`zm12`）の計算規則（累積合計と `pg_dpth` オフセット）を特定した。

### Topic 2: TSV/バンプの生成モード
- **Findings**:
  - `H2-main_TSV_Opt` では `tsv_config.json` によるランダム/マニュアル配置が導入されている。
  - 一方で `H2-main-original` では 4x4 の等間隔配置がハードコードされている。
  - 設計では、JSONがない場合にこの 4x4 配置を生成するフォールバックロジックを組み込む必要がある。

## Architecture Decisions

### Decision 1: 不変構造体による設定管理
- **Rationale**: 解析実行中に設定値が変更されることはなく、不変（`immutable struct`）にすることで、不慮の書き換えを防ぎ、コンパイラの最適化も期待できる。

### Decision 2: 累積Z座標の動的算出
- **Rationale**: ユーザーが `layers` の厚みを変更した際、手動で `zmN` を更新するのはミスを誘発するため、読み込み時に自動で配列として算出する。

## Risks & Mitigations
- **Risk**: 設定ファイルのフォーマットエラーによる実行時停止。
- **Mitigation**: 読み込み時に必須フィールドの存在チェックと型チェック（`Float64` への変換）を行い、明確なエラーを表示する。
