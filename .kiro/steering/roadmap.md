# Roadmap

## Overview
本プロジェクトは、3D-ICの熱解析において、FVMソルバーによる高精度シミュレーションと、次数低減モデル（ROM）による高速予測を組み合わせ、最適な構造パラメータを探索するシステムの構築を目的とする。

## Approach Decision
- **Chosen**: POD-RBF (固有直交分解 + 放射基底関数) による次数低減モデリング
- **Why**: 幾何学的なパラメータ（TSV配置）の変動に対して安定した予測が可能であり、将来的な適応的サンプリングへの拡張性も高いため。
- **Rejected alternatives**: 深層学習によるサロゲートモデル（必要なサンプル数が膨大になるため、初期段階では不採用）。

## Scope
- **In**: FVMの一括実行とデータ蓄積、PODによる基底抽出、RBFによるパラメータ補間、予測精度の定量的評価。
- **Out**: ソルバー内部アルゴリズムの抜本的変更、実機による熱測定。

## Constraints
- 言語: Julia 1.10+
- データ形式: JLD2 (Julia用バイナリ形式)
- パラメータ: TSVの半径、本数、座標。

## Boundary Strategy
- **Why this split**: データの生成（Generator）、圧縮（POD）、学習（Interpolator）、検証（Validator）を分離し、各フェーズで独立した品質保証を行う。
- **Shared seams to watch**: `data/raw/` におけるスナップショットの命名規則と、パラメータベクトルの正規化ルール。

## Specs (dependency order)

### Phase 1: FVM Model Generation (Completed/Active)
- [x] config-loader -- JSON設定ファイルの読み込みと定数管理。
- [x] gds-mapping -- GDSIIポリゴンの抽出。
- [x] geometry-logic -- プリミティブとGDSの統合判定。
- [x] component-generator -- TSV/バンプ配置生成。
- [x] model-builder -- IDグリッド構築の統合。
- [x] validation-plot -- モデル確認用のプロット。

### Phase 2: Offline ROM Construction (New)
- [ ] snapshot-generator -- パラメータを変化させたFVMの一括実行とデータ蓄積。 Dependencies: model-builder
- [ ] pod-engine -- スナップショット行列からのSVDによる空間基底抽出。 Dependencies: snapshot-generator
- [ ] rom-interpolator -- パラメータからPOD係数へのRBF写像の構築。 Dependencies: pod-engine
- [ ] rom-validator -- 未知データに対するROM予測精度の評価。 Dependencies: rom-interpolator

## Existing Spec Updates
- [ ] heat3ds-ext -- 温度場（θ）を `.jld2` 形式で保存する機能を `heat3ds.jl` に追加。

## Direct Implementation Candidates
- [ ] data-directory-setup -- `data/raw` および `data/models` ディレクトリの作成。
