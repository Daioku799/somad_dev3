# Requirements: component-generator

## Introduction
本コンポーネントは、密度マップ（mu）表現から物理的なTSV座標への展開（デコード）、およびはんだバンプの配置計算を担当する。
高次元パラメータを削減しつつ、物理ソルバー（FVM）が要求する厳密な幾何形状オブジェクトを生成することを目的とする。

## Boundary Context
- **In scope**:
  - 密度マップベクトル `mu` から各セルのTSV本数への変換。
  - セル内での幾何学的なTSV座標展開（グリッド配置等）。
  - TSV座標に同期したはんだバンプの自動生成。
  - 最小ピッチおよびチップ境界に対する物理的制約の検証。
- **Out of scope**:
  - `geometry-logic` が担当する幾何学的な内外判定（点判定）。
  - `model-builder` が担当するIDマップへの具体的な埋め込み処理。
  - 熱物性値の管理。
- **Adjacent expectations**:
  - `config-loader` から有効なチップ寸法、TSV半径、最小ピッチ、および密度マップ `mu` が提供されること。

## Requirements

### 1. 密度マップに基づくTSV本数計算
**Objective:** 解析エンジニアとして、密度ベクトル `mu` を指定することで、各領域のTSV密度を制御したい。

#### Acceptance Criteria
1. When `tsv_mode` が "density" に設定されている場合、The Component Generator shall 密度ベクトル `mu` の各要素を対応する密度セル（$G_x \times G_y$）の占有率 $\rho_{ij}$ として解釈する。
2. The Component Generator shall 各セル内の最大配置可能本数 $n_{max,ij}$ を、セル寸法、TSV半径、および最小ピッチ $p_{min}$ に基づいて算出する。
3. The Component Generator shall 各セル内の実TSV本数 $n_{ij}$ を、$\rho_{ij} \times n_{max,ij}$ を四捨五入した値として決定する。
4. The Component Generator shall 各セルが保持可能な最大TSV本数 $n_{max,ij}$ のマトリックスを外部（ROM生成器等）から参照可能にするための公開API `get_cell_capacities` を提供する。
5. The Component Generator shall 合計TSV本数が物理的制限 $N_{limit}$ を超えないように $\mu$ をスケーリングする共有ユーティリティ関数 `adjust_density_constraints(mu, n_max_matrix, N_limit)` を提供する。この物理的な補正処理を「Constraint Adjustment（制約調整）」と呼び、ROMにおけるデータスケーリングと区別する。

### 2. セル内での実TSV座標展開
**Objective:** 解析システムとして、密度値からFVMで使用可能な具体的な (x, y) 座標を生成したい。

#### Acceptance Criteria
1. The Component Generator shall 各セル内で算出された $n_{ij}$ 本のTSVを、指定されたレイアウト規則（既定：セル内中央寄せ格子配置）に従って配置する。
2. The Component Generator shall 生成された (x, y) 座標が、すべてのシリコンチップ層において垂直方向に完全に一致（アライメント）することを保証する。
3. While `tsv_mode` が "manual" または "random" の場合、The Component Generator shall 既存の座標リストまたはシード値に基づく生成ロジックを維持する。

### 3. はんだバンプの自動生成
**Objective:** 解析システムとして、TSVの配置に合わせて接続部のはんだバンプを自動的に生成したい。

#### Acceptance Criteria
1. The Component Generator shall 各TSVの (x, y) 座標と同期して、指定されたアンダーフィル層の中心高さにバンプオブジェクトを生成する。
2. The Component Generator shall バンプの半径を、TSVの端面を完全に覆う物理的妥当な計算式に基づいて算出する。

### 4. 物理的制約の検証
**Objective:** システム管理者として、解析実行前に物理的に不可能な配置（干渉や境界逸脱）を検出したい。

#### Acceptance Criteria
1. If 生成されたTSVまたはバンプがチップの境界（$l_x, l_y$）を逸脱する場合、The Component Generator shall 境界違反エラーを通知し、処理を中断する。
2. If TSV間の中心距離が最小ピッチ $p_{min}$ を下回る場合、The Component Generator shall 干渉違反エラーを通知し、処理を中断する。
3. The Component Generator shall すべての物理制約検証を、`geometry-logic` にデータを渡す前の前処理として実行する。

### 5. データ形式とメタデータ出力
**Objective:** 開発者として、生成された座標と元の密度マップの対応関係を追跡したい。

#### Acceptance Criteria
1. The Component Generator shall 展開された実TSV座標のリストを、`geometry-logic` が受け入れ可能な円柱プリミティブ形式で出力する。
2. The Component Generator shall 密度マップ `mu` と、それから生成された各セルのTSV本数および最終的な座標リストの対応関係をメタデータとして保持する。
