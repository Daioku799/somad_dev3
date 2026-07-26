# Roadmap

## Overview
本プロジェクトは、3D-ICの熱解析において、FVMソルバーによる高精度シミュレーションと、次数低減モデル（ROM）による高速予測を組み合わせ、最適な構造パラメータを探索するシステムの構築を目的とする。
初期実装の課題であった高次元パラメータを解決するため、TSV配置を「個別座標」から「密度マップ」表現へと移行し、GAによる最適化を実現する。

## Approach Decision
- **Chosen**: 密度マップ型TSV表現 + POD-RBF ROM + 遺伝的アルゴリズム(GA)
- **Why**: 実用径TSV（数百〜数千本）を個別座標で扱うと次元爆発が起きるため。チップ平面を $4 \times 4$ などの低解像度グリッドに分割し、セルごとの密度ベクトル `mu` をパラメータとすることで、次元削減と配置傾向の分析を両立する。
- **Rejected alternatives**: TSVファーム化（配置の柔軟性が制限されるため）、深層学習サロゲート（サンプル数要件が厳しいため）、等価熱伝導率マッピング（本プロジェクトでは「密度マップ → 実TSV座標への展開 → FVM」というフローを厳守し、物理解析の厳密性を保つため）。

## Scope
- **In**: 密度マップから実TSV座標への展開、FVMの一括実行とデータ蓄積、PODによる基底抽出、RBFによるパラメータ補間、予測精度の定量的評価、密度マップを個体とするGA最適化。
- **Out**: HPWL（配線長）計算、厳密なKOZ評価、信号TSV考慮、ソルバー内部アルゴリズムの抜本的変更。

## Constraints
- パラメータ表現: `Gx x Gy` (既定 `4x4`, 比較実験にて `2x2` 〜 `16x16` を評価) のTSV密度マップ。
- 物理計算格子: $240 \times 240$ をシステム共通の基準格子として固定。
- 制約条件: 総TSV本数上限、各セル密度上限、TSV最小ピッチ。
- FVM入力: 密度マップから展開された実TSV座標（円柱プリミティブ）。 **「密度マップ → 実TSV座標への展開 → FVM」のフローを必須とする。**

## Boundary Strategy
- **Why this split**: データの生成（Generator）、圧縮（POD）、学習（Interpolator）、検証（Validator）、最適化（Optimizer）を分離し、各フェーズで独立した品質保証を行う。特に、既存のFVMソルバー連携機能と、ROM/GA機能を明確に切り離す。
- **Shared seams to watch**: 密度マップベクトル `mu` と、それに対応する展開後実TSV座標、およびFVM温度場のデータ連携。

## Specs (dependency order)

### Phase 5: Sensitivity & Paper Evaluation
- [x] rom-paper-evaluation -- SVD減衰プロット、RBF感度ヒートマップ、ROMモデルサイズ/構築時間計測、新旧FVM等価性アサーション検証。
- [ ] rom-paper-sensitivity-sweeps -- 240x240物理格子を基準とした1因子比較実験（密度マップ解像度 2x2〜16x16, Nsnap, PODモード数, RBF関数）と精度・処理時間プロファイルレポート生成。

### Phase 2: Density Map Refactoring
- [x] config-loader -- JSON設定から `tsv_mode="density"` と密度マップ関連制約を読み込む機能の追加。 Dependencies: none
- [x] heat3ds-ext -- 温度場（θ）を `.jld2` 形式で保存する機能を `heat3ds.jl` に追加。 Dependencies: none
- [x] component-generator -- 密度マップから実TSV座標への展開ロジック、およびピッチ・チップ範囲検証の追加。 Dependencies: config-loader
- [x] snapshot-generator -- 密度マップのサンプリングによるFVM一括実行への変更。 Dependencies: component-generator, heat3ds-ext

### Phase 3: Offline ROM Construction
- [x] pod-engine -- スナップショット行列からのSVDによる空間基底抽出。 Dependencies: snapshot-generator
- [x] rom-interpolator -- 密度ベクトル `mu` からPOD係数へのRBF写像の構築。 Dependencies: pod-engine
- [x] rom-validator -- 未知密度マップに対するROM予測精度の評価。 Dependencies: rom-interpolator

### Phase 4: GA Optimization
- [x] ga-optimizer -- 密度マップを個体とするGA実装、制約修正、ROM評価、および有望解のFVM再検証。 Dependencies: rom-validator

## Phase 1: FVM Model Generation (Completed)
- [x] config-loader (初期実装)
- [x] gds-mapping
- [x] geometry-logic
- [x] component-generator (初期実装)
- [x] model-builder
- [x] validation-plot
- [x] data-directory-setup

