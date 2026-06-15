# Requirements Document

## Introduction
`pod-engine`は、FVM（有限体積法）ソルバーによって生成された高次元の温度場スナップショット群から、POD（固有直交分解）を用いて支配的な空間基底（POD Modes）を抽出する。これにより、解析精度を維持しつつ計算負荷を大幅に削減した低次元近似空間を構築し、後続のROM補間および最適化フェーズへの基盤を提供する。

## Boundary Context
- **In scope**:
    - 指定されたディレクトリ（`data/raw/`）からの複数スナップショット（.jld2）の読み込みと行列化。
    - SVD（特異値分解）によるPOD基底および特異値の計算。
    - 累積寄与率（RIC）に基づく適切な基底数 `r` の自動選定。
    - 抽出された基底データ、特異値、および各スナップショットのPOD係数（射影結果）の永続化保存。
- **Out of scope**:
    - RBF（径向基底関数）等によるパラメータ空間の補間ロジック（`rom-interpolator`の責務）。
    - 新規パラメータに対する温度場の再構成および予測実行。
    - FVMソルバー自体の実行（`snapshot-generator`の責務）。
- **Adjacent expectations**:
    - `snapshot-generator`が生成した、座標系が共通で一貫性のある `.jld2` スナップショットファイル群が `data/raw/` に存在すること。
    - 保存された基底データが `rom-interpolator` によって読み込み可能なデータ構造であること。

## Requirements

### Requirement 1: スナップショット行列の構築
**Objective:** ROM開発者として、複数のFVMスナップショットから一つのスナップショット行列を構築したい。これにより、一括した次元削減処理が可能になる。

#### Acceptance Criteria
1. When 複数のFVMスナップショットファイル（.jld2）が提供されたとき、`pod-engine` はそれらを読み込み、単一のスナップショット行列として組み立てる。
2. If スナップショットファイルのデータ構造が不整合である、または破損している場合、`pod-engine` はエラーを報告し、処理を中断する。

### Requirement 2: POD基底の抽出 (SVD)
**Objective:** ROM開発者として、スナップショット行列から支配的な空間基底を抽出したい。これにより、温度場の次元を劇的に削減できる。

#### Acceptance Criteria
1. When スナップショット行列が構成されたとき、`pod-engine` は平均場（Mean Field）を算出し、各スナップショットから減算して変動成分（Centered POD）を抽出する。
2. When スナップショット行列が準備されたとき、`pod-engine` はSVD（特異値分解）を実行し、特異値およびPOD基底（左特異ベクトル）を取得する。
3. While SVDを実行する際、`pod-engine` は累積寄与率（RIC）に基づいて保持するモード数 `r` を決定する。
4. Where 明示的なRICしきい値が指定されていない場合、`pod-engine` はデフォルト値として0.999を使用する。

### Requirement 3: POD係数の算出 (射影)
**Objective:** ROM開発者として、各スナップショットをPOD基底に射影した係数を得たい。これが後の補間モデルの学習データとなる。

#### Acceptance Criteria
1. When POD基底が抽出されたとき、`pod-engine` は各入力スナップショットを基底空間へ射影し、各スナップショットに対応するPOD係数（モーダル係数）を算出する。

### Requirement 4: 基底データと結果の保存
**Objective:** ROM開発者として、抽出された基底と係数を保存したい。これにより、後続のコンポーネント（`rom-interpolator`など）がそれらを利用できる。

#### Acceptance Criteria
1. When POD処理が完了したとき、`pod-engine` はPOD基底、特異値、平均場、および算出されたPOD係数を永続化ファイル（.jld2）に保存する。
2. **[トレーサビリティ]** `pod-engine` は、各スナップショットに対応するパラメータベクトル `mu` および `trained_snapshot_ids` を保存ファイルに含める。
3. **[物理コンテキスト]** `pod-engine` は、チップ寸法（lx, ly, lz）や格子情報などの物理メタデータを保存ファイルに含める。
4. `pod-engine` は、使用されたモード数 `r` や達成されたRIC値などのメタ情報を保存ファイルに含める。

