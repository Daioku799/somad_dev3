# Requirements Document

## Introduction
3D-ICの熱設計において、TSV（Through-Silicon Via）の配置は熱特性に大きな影響を与えます。本機能「ga-optimizer」は、遺伝的アルゴリズム（GA）を用いてTSV密度マップを最適化し、制約条件を満たしつつチップの最高温度を最小化する設計案を自動探索します。高速な評価には次数低減モデル（ROM）を使用し、最終的な有望解については物理ソルバー（FVM）による厳密な検証を行うことで、解析の効率性と信頼性を両立させます。

## Boundary Context
- **In scope**:
  - 密度マップベクトル `mu` を遺伝子（Genotype）とするGAの実装
  - 適合度評価における `H2-rom` (ROM) の呼び出し
  - `ComponentGenerator.Layout.adjust_density_constraints` に基づく「Constraint Adjustment（制約修正）」プロセス
  - ROMの外挿検知とエリート個体のFVM再検証
  - 最終解に対する「密度マップ → 実TSV座標展開 → FVM実行」の検証フロー
- **Out of scope**:
  - ROMの構築プロセス（`pod-engine`, `rom-interpolator` が担当）
  - FVMソルバー内部の計算アルゴリズムの変更
  - 信号TSVの考慮や配線長（HPWL）の最適化
- **Adjacent expectations**:
  - `config-loader` から最適化パラメータと制約設定を取得する
  - `component-generator` を用いて、密度マップを実TSV座標に展開する
  - `rom-validator` の精度評価基準を信頼性判定の参照とする

## Requirements

### Requirement 1: GAによる密度マップ最適化ループ
**Objective:** As a 熱設計者, I want GAを用いてTSV密度マップを最適化したい, so that 最高温度を最小化する設計案を得ることができる

#### Acceptance Criteria
1. When 最適化プロセスが開始される, the ga-optimizer shall 初期個体群（密度マップ `mu` の集合）を生成する
2. While 最適化ループが実行中である, the ga-optimizer shall ROMを用いて各個体の最高温度を予測し、適合度（fitness）として評価する
3. When 次世代の生成が行われる, the ga-optimizer shall 選択・交叉・突然変異の操作を密度マップベクトルに対して適用する
4. The ga-optimizer shall 適合度の推移（収束状況）を記録し、ユーザーが確認可能にする

### Requirement 2: 密度マップの制約条件管理
**Objective:** As a 設計ルール管理者, I want 最適化プロセスにおいて物理的な制約を維持したい, so that 実現不可能な設計案が生成されるのを防ぐことができる

#### Acceptance Criteria
1. The ga-optimizer shall 総TSV本数の上限、各セルの密度上限、および配置禁止領域の制約を遵守する
2. When 個体が生成または変更（交叉・突然変異）された際, the ga-optimizer shall `ComponentGenerator.Layout.adjust_density_constraints` を呼び出し、「Constraint Adjustment（制約修正）」プロセスを実行して密度マップ `mu` を物理的制約に適合させる
3. If 密度マップが制約を大幅に逸脱し、修正が困難な場合, then the ga-optimizer shall その個体を破棄し、新たな有効な個体を生成する

### Requirement 3: 予測の信頼性管理と再検証
**Objective:** As a 解析品質保証担当者, I want ROMの予測精度と物理的妥当性を保証したい, so that 信頼性の高い最適化結果を得ることができる

#### Acceptance Criteria
1. When ROMによる評価が行われる際, the ga-optimizer shall 入力された密度マップがROMの訓練範囲外（外挿）であるかを判定する
2. While 最適化の最終フェーズまたはエリート個体群の評価において, the ga-optimizer shall 上位候補に対してFVMソルバーを実行し、ROMの予測値を再検証する
3. If ROMの予測値とFVMの結果に大きな乖離がある場合, then the ga-optimizer shall 警告を発し、必要に応じてFVM結果を優先する

### Requirement 4: 最終解の物理モデル生成と検証フロー
**Objective:** As a システム統合担当者, I want 最適化された密度マップを物理的なTSV配置に変換して最終検証を行いたい, so that 物理的な整合性が完全に確認された結果を出力できる

#### Acceptance Criteria
1. When 最適化が完了し、最終解が選定された際, the ga-optimizer shall 「密度マップ → 実TSV座標への展開 → FVM解析」のフローを必須として実行する
2. The ga-optimizer shall 最終解の実TSV座標データを `component-generator` を介して生成する
3. The ga-optimizer shall 最終的なFVM解析結果（最高温度、温度場データ）をレポートとして出力する
