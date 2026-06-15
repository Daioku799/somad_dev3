# Research Log: config-loader

## Summary
- **Feature**: config-loader
- **Discovery Scope**: Extension (Density Map support)
- **Key Findings**:
  - TSV配置を「密度マップ（Density Map）」形式で扱うためのデータ構造と、GA（遺伝的アルゴリズム）およびサンプリング設定の統合が必要。
  - 密度マップは $G_x \times G_y$ のグリッド形式をとり、ベクトル $\mu$ として管理される。
  - 製造制約（アスペクト比、最小ピッチ）および最適化制約（総本数、禁止セル）をロード対象に追加。

## Research Log

### Topic 1: 密度マップ形式の統合
- **Context**: 既存の `TSVConfig` は `manual` または `random` のみ対応しており、密度マップベースの最適化を支援できない。
- **Findings**:
  - `tsv_mode="density"` の導入により、グリッド分割数 $G_x, G_y$ と密度ベクトル $\mu$ を保持する必要がある。
  - 密度マップから実座標への展開は `component-generator` が担当するが、そのための入力パラメータを `config-loader` が提供しなければならない。
- **Implications**: `TSVConfig` 構造体に `density` フィールドを追加し、オプションの `DensityMapConfig` を保持するように拡張する。

### Topic 2: 最適化および製造制約の定義
- **Context**: GAによる自動探索において、物理的に不可能な配置や製造困難なパラメータを排除するための制約が必要。
- **Findings**:
  - 制約条件: $N_{min}, N_{max}$ (総本数)、$\rho_{cell,max}$ (セル別上限)、禁止セル。
  - 製造制約: $d_{tsv}$ (直径)、$p_{min}$ (最小ピッチ)、$AR$ (アスペクト比)。
- **Implications**: これらの定数を `tsv_config.json` から読み込み、型安全な構造体として保持する。

### Topic 3: 解析・検証条件の追加
- **Context**: ROM構築のためのスナップショット生成や、精度検証のための設定が必要。
- **Findings**:
  - スナップショット保存の有効化/無効化、保存ディレクトリ。
  - 解析収束判定（$\epsilon$, max_iter）。
  - シリコン熱伝導率の固定（線形ROM検証用）。
- **Implications**: `ModelConfig` にこれらの実行制御用パラメータを追加する。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| 単一構造体 | すべてのオプションを `TSVConfig` に含める | 単純なアクセス | 密度マップを使わない場合にフィールドが冗長になる | 初期実装としては管理しやすい |
| 型階層 (AbstractType) | モードごとに異なる構造体を定義 | 型安全性が高い、冗長性がない | JSONパース後の型変換が複雑になる | Juliaのマルチディスパッチを活かせる |

## Design Decisions

### Decision: 密度マップ情報の拡張
- **Context**: 最適化プロジェクトの根幹となる密度マップ情報の統合。
- **Selected Approach**: `TSVConfig` 内にオプションの `DensityMapConfig` 構造体を保持する。
- **Rationale**: 既存の `manual` モードとの互換性を保ちつつ、密度マップに必要な情報をカプセル化できるため。

### Decision: 最適化パラメータの統合ロード
- **Context**: GAやサンプリングの設定が散逸するのを防ぐ。
- **Selected Approach**: `tsv_config.json` を主軸とし、`density_map`, `manufacturing`, `ga_settings` のセクションを設ける。
- **Rationale**: TSVに関する設定を1つのファイルに集約することで、探索ケースの管理が容易になる。

## Risks & Mitigations
- パラメータ欠落によるランタイムエラー — ロード時に `has_key` による厳格なチェックとデフォルト値の適用を行う。
- 密度マップベクトル $\mu$ のサイズ不整合 — $G_x \times G_y$ と $\mu$ の長さが一致することをロード時に検証する。

## References
- [Roadmap](../../steering/roadmap.md) — 密度マップ表現への移行方針。
- [Requirements](./requirements.md) — 詳細な要件定義。
