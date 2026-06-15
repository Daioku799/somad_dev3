# Requirements: config-loader

## 1. 設定ファイルのロードと厳格な検証
- 1.1 The Config Loader shall `config.json` および `tsv_config.json` からすべてのパラメータを読み込む。
- 1.2 提供されたJSONファイルに必要なパラメータが欠けている場合、The Config Loader shall エラーを発生させて実行を終了する。（注：解析実行時の自動補完は行わない）
- 1.3 **[絶対条件: オリジナル物理定数の再現]** The Config Loader shall すべての物理定数（Material ID, λ, ρ, Cp）およびデフォルト寸法が `H2-main-original/src/modelA.jl` で定義されたものとビットレベルで一致する完全な設定オブジェクトを生成するユーティリティ機能を提供する。
- 1.4 `tsv_mode` が "density" に設定されている場合、The Config Loader shall 密度マップ関連の設定（グリッド数、制約条件等）を読み込む。

## 2. 環境再現とパッケージ管理
- 2.1 **[Project.toml の維持]** The Config Loader（およびプロジェクト全体）は、`JSON`, `SimpleGDS`, `PolygonOps`, `Plots` の所定のバージョンに適合するよう、`Project.toml` を用いて Julia 環境が正しく初期化されることを保証する。
- 2.2 The Config Loader shall ロードされたパラメータを、下流モジュールで数値精度が維持される型安全な形式で提供する。

## 3. 幾何学パラメータの動的算出
- 3.1 `layers` 定義がロードされた場合、The Config Loader shall すべての層境界（zm0〜zm12）の累積Z座標を計算し、デフォルト層厚使用時にオリジナルマーカーと一致することを保証する。
- 3.2 The Config Loader shall PowerGrid のZ座標を、シリコン層境界からの動的なオフセット（`pg_dpth`）として、オリジナルのオフセットルールに従って計算する。

## 4. コンポーネント生成の支援
- 4.1 `tsv_config.json` の読み込み時、The Config Loader shall 配置モード（`manual`, `random`, `density`）および対応するパラメータ（座標リスト、シード値、密度グリッド等）を抽出する。
- 4.2 `random` モードが有効な間、The Config Loader shall 指定された `random_seed` を使用して、再現可能な座標生成を保証する。
- 4.3 モデルビルダーから要求された場合、The Config Loader shall 推奨されるはんだバンプ半径を `1.3 * d_ufill / 2.0` として計算する。

## 5. 密度マップおよび最適化設定の管理
- 5.1 The Config Loader shall 密度グリッド分割数（Gx, Gy）をロードし、未指定の場合は 4x4 を既定値とする。
- 5.2 The Config Loader shall 総TSV本数範囲（N_min, N_max）およびセルごとの密度上限（rho_cell_max）を含む密度制約をロードする。
- 5.3 設定ファイルで「配置禁止セル」が指定されている場合、The Config Loader shall 該当セルの密度が0であることを保証する。
- 5.4 The Config Loader shall TSVの製造制約（直径 d_tsv、最小ピッチ p_min、アスペクト比範囲）をロードする。
- 5.5 The Config Loader shall サンプリング設定（Random, LHS, 代表パターン）およびGA最適化パラメータ（個体数、世代数、交叉・突然変異率等）をロードする。

## 6. 解析・検証条件の制御
- 6.1 スナップショット保存が有効な場合、The Config Loader shall スナップショット保存用フォルダおよびファイル命名規則の設定をロードする。
- 6.2 線形ROM検証用にシリコン熱伝導率の固定が指定された場合、The Config Loader shall 指定された値（例：100 W/mK）を物性値として採用する。
- 6.3 The Config Loader shall FVMソルバーの収束判定条件（epsilon）および最大反復回数をロードする。

## Scope Boundaries
- **In**: 設定JSONのパース、オリジナル準拠の物理定数管理、累積Z座標の計算、環境初期化の支援、密度マップおよび最適化設定のロード。
- **Out**: GDSIIファイルのバイナリパース（`gds-mapping`が担当）、具体的なメッシュ生成（`model-builder`が担当）、密度マップから実座標への展開（`component-generator`が担当）。
