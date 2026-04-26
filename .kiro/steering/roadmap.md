# Roadmap

## Overview
H2-main_TSV_Optの調査結果に基づき、H2-main-copyにおいて熱解析モデル構築プログラムを再構成します。外部ファイル（JSON/GDSII）による柔軟なパラメータ設定と、幾何プリミティブによる安定した格子マッピングを両立させ、最適化プロセスに適した設計を目指します。

## Approach Decision
- **Chosen**: モジュール化されたハイブリッド・モデリング・アーキテクチャ
- **Why**: オリジナルの高速な幾何判定と、拡張版の柔軟な外部連携を分離することで、メンテナンス性と計算速度を両立させるため。
- **Rejected alternatives**: 単純なH2-main_TSV_Optのコピー（コードが複雑化しすぎているため却下）。

## Scope
- **In**: JSON/GDSII連携、動的な層構造計算、TSV/はんだバンプの自動生成ロジック、YZ/XY断面プロット。
- **Out**: 熱解析ソルバー（heat3ds.jl等）本体の改修、GUIの実装。

## Constraints
- Julia言語を使用。
- オリジナルの `H2-main-original` と同じ入力を与えた際に、物理的に妥当な（または一致する）モデルを生成すること。
- メッシュ解像度は 240x240x31 を基本とする。

## Boundary Strategy
- **Why this split**: データの読み込み、幾何計算、コンポーネント生成を分離することで、各機能を独立してテスト可能にする。
- **Shared seams to watch**: `Z` 座標ベクトルの定義と、各層の境界インデックス計算。

## Specs (dependency order)
- [ ] config-loader -- JSON設定ファイルの読み込みと定数管理。 Dependencies: none
- [ ] gds-mapping -- GDSIIポリゴンの抽出と包含判定の抽象化。 Dependencies: none
- [ ] geometry-logic -- プリミティブとGDSを統合した内外判定ロジック。 Dependencies: gds-mapping
- [ ] component-generator -- TSVとはんだバンプの配置・生成。 Dependencies: config-loader
- [ ] model-builder -- IDグリッドの充填とモデル構築の統合。 Dependencies: config-loader, geometry-logic, component-generator
- [ ] validation-plot -- モデル確認用のプロット機能。 Dependencies: model-builder
