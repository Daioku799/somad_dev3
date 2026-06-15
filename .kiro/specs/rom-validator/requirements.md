# Requirements Document

## Introduction
本ドキュメントは、構築された次数低減モデル（ROM）の予測精度を、未知のTSV密度マップ（学習に使用していないパラメータ）に対して定量的に検証するための「rom-validator」の要件を定義する。

## Boundary Context
- **In scope**: 未知の密度マップに対するROM予測の実行、FVM解析結果との比較計算、温度場全体の相対誤差およびTmax誤差の算出、ホットスポット位置の精度評価、評価レポートの生成。
- **Out of scope**: 学習用データの生成（snapshot-generatorが担当）、ROMの学習自体（rom-interpolatorが担当）。
- **Adjacent expectations**: `rom-interpolator` によって構築されたモデルがロード可能であること、`data/raw/` にFVMによる正解データ（スナップショット）が存在すること。

## Requirements

### Requirement 1: 精度評価指標の算出
**Objective:** 研究者として、ROMの予測結果とFVMの解析結果の間の各種誤差指標を計算し、ROMの性能を定量的に把握したい。

#### Acceptance Criteria
1. When 検証用スナップショットを評価する際, the system shall 温度場全体の相対L2誤差を算出する。
2. When 検証用スナップショットを評価する際, the system shall 最高温度誤差（Tmax誤差：FVMの最高温度とROMの最高温度の差）を算出する。
3. When 検証用スナップショットを評価する際, the system shall ROMが予測したホットスポット（最高温度地点）とFVMが算出したホットスポットの間の幾何学的距離を算出する。
4. The system shall すべての検証用スナップショットにわたる各指標の平均値および最大値をレポートする。

### Requirement 2: 検証用データセットの管理
**Objective:** 研究者として、検証用に指定された特定のデータセットを読み込み、ROMが未知のデータに対して評価されることを保証したい。

#### Acceptance Criteria
1. While 検証データを読み込む際, the system shall `data/raw/` から、ROMの学習（補間モデルの構築）に使用されなかったスナップショットを自動的に特定する。
2. The system shall 各検証ケースについて、密度マップ（入力パラメータベクトル）と対応するFVM温度場（正解データ）の両方を読み込む。

### Requirement 3: 合格判定基準の適用
**Objective:** システム運用者として、ROMの精度が規定の閾値を満たしているか判定し、最適化フェーズへの移行可否を決定したい。

#### Acceptance Criteria
1. The system shall Tmax平均誤差を既定の閾値（例: 2.0 K）と比較する。
2. If Tmax平均誤差が閾値を超える場合, the system shall 当該ROMを「最適化に使用不可（精度不足）」と判定する。
3. Where すべての精度指標が規定の閾値以内である場合, the system shall 当該ROMを「検証済み」としてマークする。

### Requirement 4: 視覚化とレポート生成
**Objective:** ユーザーとして、ROMとFVMの結果の視覚的な比較を確認し、予測品質を定性的に検証したい。

#### Acceptance Criteria
1. When 検証が完了した際, the system shall すべての指標をまとめた評価レポート（MarkdownまたはJSON形式）を生成する。
2. The system shall 選択された検証ケースについて、ROMの予測値、FVMの解析値、およびそれらの差分（誤差マップ）を並べた比較断面プロットを生成する。
