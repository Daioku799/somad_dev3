# Requirements Document

## Introduction
密度マップベクトル `mu` を入力とし、POD係数 `a` を出力する非線形補間モデル（RBF: 放射基底関数）を構築し、温度場を再構成する機能を提供する。

## Boundary Context
- **In scope**: RBF重みの学習、学習データの保存・読込、入力パラメータ（密度マップ）のデータスケーリング（Data Scaling）処理、未知パラメータに対するPOD係数の予測、および温度場の再構成。
- **Out of scope**: POD基底の抽出（`pod-engine` が担当）、再構成結果の誤差評価（`rom-validator` が担当）、最適化ループの実行（`ga-optimizer` が担当）。
- **Adjacent expectations**: `pod-engine` によって生成された、学習用の密度マップ `mu` とPOD係数 `a` のペアが利用可能であること。

## Requirements

### Requirement 1: 抽象補間インターフェースとRBFモデルの学習
**Objective:** 解析エンジニアとして、補間アルゴリズム（モーダル係数決定法）をオプショナルで変更可能としつつ、デフォルトでRBFを用いて学習を安定させたい。

#### Acceptance Criteria
1. The `rom-interpolator` shall 抽象型 `AbstractInterpolator` またはそれに準じるインターフェースを定義し、具体的な決定アルゴリズムを分離（オプショナルに切り替え可能）すること。
2. When 学習データセット（密度マップ `mu` とPOD係数 `a` のペア）が提供されたとき、`fit!(interpolator::AbstractInterpolator, X::Matrix{Float64}, Y::Matrix{Float64})` などの統一された API で重みを学習できること。
3. The `rom-interpolator` shall デフォルトの具象実装としてガウスカーネル（Gaussian Kernel）を用いた RBF ネットワークモデル (`RBFInterpolator`) を提供すること。
4. If 学習データが不適切（サンプル数が不足している、または次元が不一致など）な場合、補間エンジンの学習時にエラーを表示して処理を中断すること。

### Requirement 2: 入力データのデータスケーリング（Data Scaling）
**Objective:** 解析エンジニアとして、密度マップの各セル値をデータスケーリング（Data Scaling）することで、学習を安定させ予測精度を向上させたい。

#### Acceptance Criteria
1. The `rom-interpolator` shall 密度マップベクトル `mu` の各要素を、学習および予測の前に適切な範囲（例: $[0, 1]$）にデータスケーリング（Data Scaling）すること。
2. When 予測実行時、`rom-interpolator` は入力された密度マップに対し、学習時と同一のデータスケーリング（Data Scaling）パラメータ（最小値・最大値等）を適用すること。

### Requirement 3: POD係数の予測と温度場の再構成
**Objective:** 解析エンジニアとして、未知の密度マップから瞬時に温度場を予測し、設計空間の探索を高速化したい。

#### Acceptance Criteria
1. When 未知の密度マップベクトルが入力されたとき、`rom-interpolator` は学習済みRBFモデルを用いてPOD係数を算出すること。
2. When POD係数が算出されたとき、`rom-interpolator` は別途読み込まれたPOD基底との線形結合により、グリッド上の温度場ベクトルを再構成すること。
3. The `rom-interpolator` shall 再構成された温度場を、元の3次元グリッド形状（または指定された出力形式）に変換して出力すること。
4. The `rom-interpolator` shall 再構成された 3D 温度場ベクトルから最高温度を抽出するユーティリティ関数 `get_tmax(theta)` を提供すること。

### Requirement 4: モデルの永続化
**Objective:** 解析エンジニアとして、学習済みのRBFモデルを保存・再利用することで、計算リソースを節約し再現性を確保したい。

#### Acceptance Criteria
1. When 学習が正常に完了したとき、`rom-interpolator` は算出されたRBF重みおよびデータスケーリング（Data Scaling）パラメータを永続化ファイル（例: `.jld2`）に保存すること。
2. When モデルの読込が要求されたとき、`rom-interpolator` は指定されたファイルから学習済みモデルを復元すること。

### Requirement 5: 予測の信頼性評価（外挿検知）
**Objective:** 解析エンジニアとして、入力パラメータが学習データの範囲外（外挿）である場合にそれを検知しつつ、判定アルゴリズムを将来的に差し替え可能にしたい。

#### Acceptance Criteria
1. The `rom-interpolator` shall 入力された密度マップ `mu` が学習データの範囲内にあるかを判定する API `is_reliable(interpolator, mu)` を提供すること。
2. **[デフォルト判定 (案A)]** `is_reliable` のデフォルトの実装として、学習データの各セルごとの最小値・最大値の範囲 $[mu_{min, i}, mu_{max, i}]$ 内に入力 `mu` のすべてのセル値が収まっているかを検証するボックス型チェックを採用すること。
3. **[拡張性]** 信頼性判定処理は、学習されたデータ構造から独立した判定関数、または多重ディスパッチによって定義され、将来的に凸包（Convex Hull）判定や距離ベース判定などの高度な幾何判定アルゴリズムへ容易に差し替えができる設計とすること。
