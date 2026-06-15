# Roadmap (Updated)

## Overview
本プロジェクトは、3D-ICの熱解析において、FVMソルバーによる高精度シミュレーションと、次数低減モデル（ROM）による高速予測を組み合わせ、最適な構造パラメータを探索するシステムの構築を目的とする。

## Approach Decision
- **Chosen**: POD-RBF による次数低減モデリング
- **Why**: 幾何学的なパラメータ（TSV配置）の変動に対して安定した予測が可能。

## Scope
- **In**: FVMの一括実行とデータ蓄積、PODによる基底抽出、RBFによるパラメータ補間、予測精度の定量的評価、高解像度円柱TSV、側面断熱境界。
- **Out**: KOZ制約、シリコン熱伝導率の動的温度依存性（平均値運用）。

## Specs (dependency order)

### Phase 1: Model Refinement (Active)
- [ ] config-loader -- TSV径(5um)およびシリコン熱伝導率(100W/mK)の更新。
- [ ] heat3ds-ext -- 側面断熱境界の実装および高解像度格子への対応確認。

### Phase 2: Offline ROM Construction
- [ ] snapshot-generator -- パラメータを変化させたFVMの一括実行とデータ蓄積。
- [ ] pod-engine -- スナップショット行列からのSVDによる空間基底抽出。
- [ ] rom-interpolator -- パラメータからPOD係数へのRBF写像の構築。
- [ ] rom-validator -- 未知データに対するROM予測精度の評価。
