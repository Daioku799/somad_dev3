# Requirements: config-loader

## 1. 設定ファイルのロードと厳格な検証
- 1.1 The Config Loader shall read all parameters from `config.json` and `tsv_config.json`.
- 1.2 If any required parameter is missing from the provided JSON files, the Config Loader shall raise an error and terminate execution. (注: 解析実行時の自動補完は行わない)
- 1.3 **[絶対条件: オリジナル物理定数の再現]** The Config Loader shall provide a utility function to generate a complete configuration object where all physical constants (Material ID, λ, ρ, Cp) and default dimensions are bit-for-bit identical to those defined in `H2-main-original/src/modelA.jl`.

## 2. 環境再現とパッケージ管理
- 2.1 **[Project.toml の維持]** The Config Loader (and the project as a whole) shall ensure that the Julia environment is correctly initialized using `Project.toml`, matching the required versions of `JSON`, `SimpleGDS`, `PolygonOps`, and `Plots`.
- 2.2 The Config Loader shall provide the loaded parameters in a type-safe format that preserves numeric precision for downstream modules.

## 3. 幾何学パラメータの動的算出
- 3.1 When the `layers` definition is loaded, the Config Loader shall calculate cumulative Z coordinates for all 13 layer boundaries (zm0 to zm12), ensuring they match original markers when using default thicknesses.
- 3.2 The Config Loader shall calculate the Z coordinate for the PowerGrid as a dynamic offset (`pg_dpth`) from the Silicon layer boundary, matching the original offset rule.

## 4. コンポーネント生成の支援
- 4.1 When `tsv_config.json` is read, the Config Loader shall extract the placement mode (`manual` or `random`) and the corresponding coordinate list.
- 4.2 While the `random` mode is active, the Config Loader shall use the specified `random_seed` to ensure reproducible coordinate generation.
- 4.3 The Config Loader shall calculate the recommended solder bump radius as `1.3 * d_ufill / 2.0` when requested by the model builder.

## Scope Boundaries
- **In**: 設定JSONのパース、オリジナル準拠の物理定数管理、累積Z座標の計算、環境初期化の支援。
- **Out**: GDSIIファイルのバイナリパース（`gds-mapping`が担当）、具体的なメッシュ生成（`model-builder`が担当）。

