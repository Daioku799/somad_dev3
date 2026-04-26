# Requirements: config-loader

## 1. 設定ファイルのロードと厳格なバリデーション
- 1.1 The Config Loader shall read all parameters from `config.json` and `tsv_config.json`.
- 1.2 If any required parameter is missing from the provided JSON files, the Config Loader shall raise an error and terminate execution. (注: 解析実行時の自動補完は行わない)
- 1.3 **[試験用初期値の設定]** The Config Loader shall provide a utility function to generate a complete configuration object where any unspecified parameters are populated with `H2-main-original` values for testing purposes.

## 2. パラメータの検証と提供
- 2.1 The Config Loader shall provide the loaded parameters in a type-safe format that preserves numeric precision for downstream modules.
- 2.2 If a loaded physical constant (e.g., thermal conductivity λ) is less than or equal to zero, the Config Loader shall notify a validation error and stop.

## 3. 幾何学パラメータの動的算出
- 3.1 When the `layers` definition is loaded, the Config Loader shall calculate cumulative Z coordinates for all 13 layer boundaries (zm0 to zm12).
- 3.2 The Config Loader shall calculate the Z coordinate for the PowerGrid as a dynamic offset (`pg_dpth`) from the top boundary of its containing Silicon layer.

## 4. コンポーネント生成の支援
- 4.1 When `tsv_config.json` is read, the Config Loader shall extract the placement mode (`manual` or `random`) and the corresponding coordinate list.
- 4.2 While the `random` mode is active, the Config Loader shall use the specified `random_seed` to ensure reproducible coordinate generation.
- 4.3 The Config Loader shall calculate the recommended solder bump radius as `1.3 * d_ufill / 2.0` when requested by the model builder.

## Scope Boundaries
- **In**: 設定JSONのパース、試験用データの生成（H2-main-original準拠）、累積Z座標の計算。
- **Out**: GDSIIファイルのバイナリパース（`gds-mapping`が担当）、具体的なメッシュ生成（`model-builder`が担当）。
