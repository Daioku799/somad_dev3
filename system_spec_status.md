# システム仕様・進捗状況ダッシュボード (System Specification & Progress Dashboard)

本プロジェクト（3D-IC熱最適化システム）を構成する各モジュール（仕様）の役割、および現在の実装状況（実装済み / 未実装）の一覧です。

```mermaid
graph TD
    classDef finished fill:#d4edda,stroke:#28a745,stroke-width:2px;
    classDef progress fill:#fff3cd,stroke:#ffc107,stroke-width:2px;

    Config[config-loader]:::finished --> Model[model-builder]:::finished
    Geom[geometry-logic]:::finished --> Model
    GDS[gds-mapping]:::finished --> Model
    Model --> FVM[heat3ds-ext]:::finished
    FVM --> Snap[snapshot-generator]:::finished
    Snap --> POD[pod-engine]:::finished
    POD --> ROM[rom-interpolator]:::finished
    ROM --> Val[rom-validator]:::finished
    ROM --> GA[ga-optimizer]:::finished
    ValPlot[validation-plot]:::finished
```

---

## 1. コンポーネント一覧と進捗状況

| コンポーネント名 | 主な役割 | 進捗状況 | 関連ファイルへのリンク |
| :--- | :--- | :---: | :--- |
| **`config-loader`** | 設定 JSON ファイルの パース、バリデーション、およびシステム共通設定オブジェクトの生成。 | 🟢 **実装完了** | [spec](file:///home/somadwsl/somad_dev3/.kiro/specs/config-loader/requirements.md) / [tasks](file:///home/somadwsl/somad_dev3/.kiro/specs/config-loader/tasks.md) |
| **`component-generator`** | 各種デバイス構造（TSV、熱源、はんだなど）の配置パラメータの生成と、FVM用グリッド割り当てロジック。 | 🟢 **実装完了** | [spec](file:///home/somadwsl/somad_dev3/.kiro/specs/component-generator/requirements.md) / [tasks](file:///home/somadwsl/somad_dev3/.kiro/specs/component-generator/tasks.md) |
| **`geometry-logic`** | 各セル重心がプリミティブ（直方体・円柱・球）に含まれるかどうかの幾何判定と、BBoxによる早期棄却による高速化。 | 🟢 **実装完了** | [spec](file:///home/somadwsl/somad_dev3/.kiro/specs/geometry-logic/requirements.md) / [tasks](file:///home/somadwsl/somad_dev3/.kiro/specs/geometry-logic/tasks.md) |
| **`gds-mapping`** | GDSIIレイヤーからのレイアウト（多角形ポリゴン）の読み込み、およびチップ座標系へのマッピングと包含判定。 | 🟢 **実装完了** | [spec](file:///home/somadwsl/somad_dev3/.kiro/specs/gds-mapping/requirements.md) / [tasks](file:///home/somadwsl/somad_dev3/.kiro/specs/gds-mapping/tasks.md) |
| **`model-builder`** | 3D解析グリッドの自動生成、材料IDマップ（ID-map）の充填、および物性値（熱伝導率等）の格子へのマッピング。 | 🟢 **実装完了** | [spec](file:///home/somadwsl/somad_dev3/.kiro/specs/model-builder/requirements.md) / [tasks](file:///home/somadwsl/somad_dev3/.kiro/specs/model-builder/tasks.md) |
| **`heat3ds-ext`** | 3次元FVMシミュレータ `heat3ds.jl` の拡張。設計パラメータ `mu` の受け取りと、結果の自動 JLD2 保存機能。 | 🟢 **実装完了** | [spec](file:///home/somadwsl/somad_dev3/.kiro/specs/heat3ds-ext/requirements.md) / [tasks](file:///home/somadwsl/somad_dev3/.kiro/specs/heat3ds-ext/tasks.md) |
| **`snapshot-generator`** | 密度マップのサンプリング（LHS等）および、制約（総TSV本数等）の検証を行った上でのFVM一括実行自動制御。 | 🟢 **実装完了** | [spec](file:///home/somadwsl/somad_dev3/.kiro/specs/snapshot-generator/requirements.md) / [tasks](file:///home/somadwsl/somad_dev3/.kiro/specs/snapshot-generator/tasks.md) |
| **`pod-engine`** | スナップショット行列の構築、SVD（特異値分解）による空間基底（PODモード）抽出、およびRIC寄与率に基づく次元削減。 | 🟢 **実装完了** | [spec](file:///home/somadwsl/somad_dev3/.kiro/specs/pod-engine/requirements.md) / [tasks](file:///home/somadwsl/somad_dev3/.kiro/specs/pod-engine/tasks.md) |
| **`rom-interpolator`** | POD係数と密度マップ `mu` を紐付ける RBF 補間モデルの構築・学習・予測・保存、および温度場の3D再構成。 | 🟢 **実装完了** | [spec](file:///home/somadwsl/somad_dev3/.kiro/specs/rom-interpolator/requirements.md) / [tasks](file:///home/somadwsl/somad_dev3/.kiro/specs/rom-interpolator/tasks.md) |
| **`rom-validator`** | 未学習データに対する予測誤差（L2、Tmax、幾何位置）算出、合否判定、および統一断面比較プロット・レポート生成。 | 🟢 **実装完了** | [spec](file:///home/somadwsl/somad_dev3/.kiro/specs/rom-validator/requirements.md) / [tasks](file:///home/somadwsl/somad_dev3/.kiro/specs/rom-validator/tasks.md) |
| **`validation-plot`** | 最適化された密度マップや、実座標に展開されたTSV配置のレイアウトなどを可視化する個別プロット機能。 | 🟢 **実装完了** | [spec](file:///home/somadwsl/somad_dev3/.kiro/specs/validation-plot/requirements.md) / [tasks](file:///home/somadwsl/somad_dev3/.kiro/specs/validation-plot/tasks.md) |
| **`ga-optimizer`** | 遺伝的アルゴリズムによる最適密度マップ探索。交叉・突然変異、制約修正、ROM高速評価、外防検知、FVM再検証を含む。 | 🟢 **実装完了** | [spec](file:///home/somadwsl/somad_dev3/.kiro/specs/ga-optimizer/requirements.md) / [tasks](file:///home/somadwsl/somad_dev3/.kiro/specs/ga-optimizer/tasks.md) |
| **`rom-paper-evaluation`** | 論文発表用評価・データ収集。SVD減衰・RIC推移プロット、RBFスイープ感度解析、ROMモデルサイズ/構築時間計測、レガシーFVM等価性検証。 | 🟡 **拡張進行中** (1因子比較実験定義完了) | [spec](file:///home/foo/somad_dev3/.kiro/specs/rom-paper-evaluation/requirements.md) / [tasks](file:///home/foo/somad_dev3/.kiro/specs/rom-paper-evaluation/tasks.md) |

---

## 2. 開発優先度とロードマップ

コアシステムの全13モジュールの基礎実装・検証は完了しており、現在は論文用の **1因子比較実験（密度マップ解像度・Nsnap・PODモード数・RBFパラメータの評価）** フェーズに移行しています。

### 実装・テスト完了状況
- [x] **Phase 1: FVM Model Generation**
- [x] **Phase 2: Density Map Refactoring** (`snapshot-generator`, `heat3ds-ext`, `component-generator` 等のテストが正常終了)
- [x] **Phase 3: Offline ROM Construction** (`pod-engine`, `rom-interpolator`, `rom-validator` のテストが正常終了)
- [x] **Phase 4: GA Optimization** (`ga-optimizer` の実装、制約修正、ROM評価、FVM再検証のテストが正常終了)
- [x] **Phase 5: Paper Evaluation & Legacy Equivalence Verification** (`rom-paper-evaluation` の全評価プロット生成・新旧等価性アサーションパス)
- [ ] **Phase 5 Ext: 1-Factor Sensitivity Sweeps** (基準物理格子 240x240, 密度マップ解像度 2x2〜16x16, Nsnap, PODモード数の個別比較実験)

---

## 3. 次のステップ
基準計算格子 $240 \times 240$ に基づく1因子比較実験（密度マップ解像度 $Gx \times Gy$ 等のスイープ）の実装・データ収集を推進します。


