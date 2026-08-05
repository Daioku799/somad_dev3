# TSV密度マップを用いたROM性能評価：実験1–4

作成日: 2026-08-06  
対象: 3D-IC熱伝導FVMとPOD–Gaussian RBF ROM  
位置づけ: 研究室進捗報告用の再評価結果。学会原稿へ使用する前に、本書末尾の追加検証が必要である。

## 1. この報告書の結論

保存済み結果を監査し、実験1A、1B、2、3、4を再計算・再作図した。主要な結論は次の通りである。

1. **ROM入力表現の解像度（実験1A）と、実TSV配置を生成する解像度（実験1B）は分けて評価する必要がある。**
2. 実験1Aでは、保存case configを現行配置器で再展開した場合、4×4入力が今回の固定validationで最小の平均L2誤差を示した。2×2では空間情報の集約と範囲外ケースの影響が重なり、特にTmax予測が大きく悪化した。
3. 実験1Bでは、16×16参照配置からの配置距離とFVM温度場差に強い対応があった（Pearson `r=0.944`, `n=60`）。ただしTmax差は単調ではない。
4. 学習snapshot数を5から40へ増やすと温度場L2は改善したが、Tmaxは単調改善しなかった。また、改善の一部は保持PODモード数が4から39へ同時に増えた効果である。
5. PODモードを増やすと射影誤差は継続して下がるが、POD–RBF全体の誤差は15–20モード付近から約0.079%で飽和した。高モード域ではRBF係数補間が主要な制約となっている。
6. Gaussian RBFの最適条件は評価目的によって異なる。温度場L2重視では `(epsilon, lambda)=(0.5, 1e-2)`、Tmax重視では `(2.0, 1e-2)` が最良だった。

ただし、実験2–4で使用した10ケースは設定選択にも使用しているため、以下では**固定validation**と呼ぶ。独立した最終testではない。

## 2. 実験構成と比較範囲

| 実験 | 研究上の問い | 固定するもの | 変更するもの | データ規模 | 評価状態 |
|---|---|---|---|---:|---|
| 1A | 同一物理形状に対するROM入力解像度の影響 | FVM形状、温度場、split、POD/RBF設定 | 入力符号化 2×2–16×16 | 40 train / 10 validation | 修正版による予備評価 |
| 1B物理 | 配置生成解像度が実形状と温度場をどれだけ変えるか | 16×16 master、TSV総数、FVM条件 | 配置生成 2×2–16×16 | 20 matched masters × 4 | 報告可能な物理感度 |
| 1B ROM | 配置生成解像度別のROM性能 | master split、RBF設定 | 配置・FVM・入力次元 | 16 train / 4 holdout | 探索的結果のみ |
| 2 | 学習snapshot数の影響 | validation 10件、RBF設定 | train数 5–40、付随するPODモード | 最大40 train / 10 validation | 単一subset系列の予備評価 |
| 3 | POD保持モード数の影響 | train/validation、RBF設定 | PODモード 1–39 | 40 train / 10 validation | 予備評価 |
| 4 | Gaussian RBFパラメータ感度 | train/validation、POD 39モード | epsilon 5値、lambda 4値 | 40 train / 10 validation | validation上のチューニング |

### 2.1 データセットの違い

実験群には二つのFVM格子が混在する。誤差値を無条件に横比較してはならない。

| 使用実験 | 物理格子 | 保存配列 | TSV条件 | 備考 |
|---|---:|---:|---|---|
| 1A、2、3、4 | 60×60×30 | ghost込み62×62×32 | 直径40 µm、実配置40–48本 | 既存50ケース |
| 1B | 240×240×30 | ghost込み242×242×32 | 直径40 µm、各ケース16本 | 新規matched-master 80ケース |

入力表現も異なる。実験1Aは再構成配置のセル別TSV本数を共通上限120で割った値を使い、実験2–4はmanifestに保存された連続値 `mu` を使う。このため、同じsplit・PODモード数・RBF設定でも1Aの4×4と実験2–4の数値は完全には一致しない。

旧summaryに記載されていた「実験2–4は240×240」という表記は保存JLD2および実行コードと一致しないため、本書では採用しない。

## 3. 共通ROM手順と評価指標

### 3.1 POD–RBF ROM

train温度場を列方向へ並べたsnapshot行列を `X` とし、train平均場を差し引いてSVDする。

```text
X - mean(X) ≈ U_k Σ_k V_kᵀ
T_ROM(mu) = mean(X) + U_k a_hat(mu)
```

`a_hat(mu)` は、密度マップ入力 `mu` からPOD係数へのGaussian RBF補間である。

```text
phi(r) = exp(-(epsilon * r)^2)
```

RBF学習前に各入力次元をtrain内の最小値・最大値でスケーリングする。

### 3.2 指標

本書では次を併記する。

1. 絶対温度基準L2誤差

   ```text
   100 ||T_ROM - T_FVM||_2 / ||T_FVM||_2  [%]
   ```

2. 300 Kからの温度上昇量基準L2誤差

   ```text
   100 ||T_ROM - T_FVM||_2 / ||T_FVM - 300 K||_2  [%]
   ```

3. 最大温度誤差

   ```text
   |max(T_ROM) - max(T_FVM)|  [K]
   ```

4. POD射影誤差

   holdout真値を既存POD基底へ直接射影した場合の誤差であり、その基底でRBF補間を完全に行えた場合の下限を表す。

5. 実験1Bの物理感度

   16×16配置を参照とした対称Chamfer距離、温度場L2差、温度上昇量基準L2差、Tmax差を使用する。

現在のL2は保存配列全体、すなわちghost cellを含む。絶対温度基準L2は約300 Kの基準温度を分母に含むため小さく見える。そのため温度上昇量基準L2も必ず併記する。

## 4. 実験1A：同一物理形状に対するROM入力解像度

### 4.1 目的

FVM形状とFVM温度場を変えず、ROMへ渡す空間表現だけを2×2、4×4、8×8、16×16へ変更したときの予測性能を比較する。

### 4.2 監査による修正

旧1A evaluatorは現在の既定値を用い、`p_min=50 µm`, `n_max=16` の16本配置を再生成していた。しかし既存50ケースのFVMは、保存case config上では `p_min=80 µm`, `n_max=120`、実配置40–48本で生成されていた。このため旧1Aの入力とFVM形状は対応していなかった。

修正版では各 `data/work/case_<id>/config.json` と `tsv_config.json` から当時の物理配置を再構成する。各解像度のセル別TSV本数を共通上限120で割り、ケースごとの総TSV数を保持した入力特徴とした。旧1Aフォルダは変更せず、修正版を別フォルダへ保存した。

### 4.3 手順

1. manifestの成功50ケースをID順に使用する。
2. case 1–40をtrain、41–50を固定validationとする。
3. 保存case configから実TSV座標を再構成する。
4. 同じ座標を2×2、4×4、8×8、16×16セルで数え直す。
5. 各セル本数を共通上限120で正規化する。
6. train温度場からPODを一度構築する。RIC閾値は0.9999、保持39モードである。
7. 各入力解像度についてGaussian RBFを別々に学習する。`epsilon=1.0`, `lambda=1e-6` とする。
8. 同じ10 validation温度場を評価する。FVMは再実行しない。

### 4.4 結果

| 入力解像度 | 入力次元 | 平均L2 [%] | 中央値L2 [%] | 平均上昇量L2 [%] | 平均Tmax誤差 [K] | 軸別train範囲内 |
|---:|---:|---:|---:|---:|---:|---:|
| 2×2 | 4 | 0.43353 | 0.38435 | 3.7255 | 25.3292 | 9/10 |
| 4×4 | 16 | **0.07651** | **0.06998** | **0.6577** | 0.1343 | 8/10 |
| 8×8 | 64 | 0.09686 | 0.09046 | 0.8327 | **0.1326** | 8/10 |
| 16×16 | 256 | 0.09706 | 0.09084 | 0.8344 | 0.1340 | 8/10 |

全解像度でtrain入力は40種類すべて一意であり、validation入力とtrain入力の完全一致はなかった。

![実験1A精度比較](../plots/for_paper/01a_rom_input_resolution_reconstructed/accuracy_vs_input_resolution.png)

*図1: 同一保存FVMを用いた入力解像度比較。丸は各validationケース、×は各特徴量がtrainのmin–max範囲外のケース、線は平均と中央値を示す。*

![実験1A入力符号化](../plots/for_paper/01a_rom_input_resolution_reconstructed/same_geometry_input_encodings.png)

*図2: 同じ保存物理配置を4種類の空間解像度で符号化した例。セル内の数字はTSV本数、色は本数/120である。*

![実験1A誤差場](../plots/for_paper/01a_rom_input_resolution_reconstructed/fixed_geometry_error_fields.png)

*図3: 同一validationケースに対する絶対誤差場。4解像度で共通カラースケールを使用する。*

### 4.5 考察

- 2×2では空間分布が4値へ集約され、異なる局所配置を区別しにくいことが悪化の一因と考えられる。さらにcase 45は軸別train範囲外で、L2 `0.9116%`、Tmax誤差 `77.14 K`となり、平均を押し上げている。
- 4×4は今回のFVM生成時の密度マップと同じ区画であり、平均・中央値の温度場L2が最小だった。
- 8×8と16×16の結果はほぼ同じである。40 trainという標本数では、高次元化に見合う追加情報をRBFが利用できていない可能性がある。
- 8×8の平均Tmax誤差は最小だが、4×4との差は約0.002 Kであり、単一splitのばらつきより十分小さい。Tmaxについて8×8が優位とは結論しない。
- 保存case configから再構成した配置を使用しているが、実座標そのものはJLD2へ保存されていない。原稿用runでは実座標とlayout hashをsnapshotへ直接保存するべきである。

数値表: [実験1A summary](../plots/for_paper/01a_rom_input_resolution_reconstructed/experiment_1a_summary.tsv)、[validationケース別結果](../plots/for_paper/01a_rom_input_resolution_reconstructed/experiment_1a_holdout_cases.tsv)

## 5. 実験1B：配置生成解像度

### 5.1 目的

同じ16×16 binary master occupancyを粗視化し、各解像度でTSVを再配置したとき、物理配置とFVM温度場がどの程度変化するかを調べる。さらに、各解像度で別々に構築したROMの予備性能を確認する。

### 5.2 手順

1. seed `20260805`で20個の16×16 master occupancyを作る。
2. 各masterは占有セル16個、TSV総数16本とする。
3. 2×2、4×4、8×8へブロック集約する。16×16を参照とする。
4. 各粗セルの本数を、その解像度における実配置候補数で割る容量補正を行う。
5. 配置後にセル別本数と総数16を検証する。
6. 各master・各解像度について240×240×30 FVMを実行する。
7. ROMではmaster 1–16をtrain、17–20をholdoutとし、同一masterがsplitをまたがないようにする。

20 master×4解像度の80 FVMが揃っている。manifest上は78 `success`、2 `cached`、失敗記録なしである。

### 5.3 物理感度結果

| 配置解像度 | master数 | 平均Chamfer距離 [µm] | 平均絶対T場差 [%] | 平均上昇量場差 [%] | 平均Tmax差 [K] |
|---:|---:|---:|---:|---:|---:|
| 2×2 | 20 | 142.260 | 0.16199 | 1.3040 | 0.20881 |
| 4×4 | 20 | 76.039 | 0.12410 | 0.9990 | **0.06054** |
| 8×8 | 20 | 43.328 | 0.09643 | 0.7765 | 0.16497 |
| 16×16 | 20 | 0 | 0 | 0 | 0 |

![実験1B物理感度](../plots/for_paper/01b_placement_resolution/physical_sensitivity_vs_resolution.png)

*図4: 20 masterの2×2、4×4、8×8各点と平均。参照16×16のゼロ点は省略した。平均では解像度が粗いほど配置距離・温度場全体差が増えるが、Tmax差は単調でない。*

![配置距離と温度場差](../plots/for_paper/01b_placement_resolution/geometry_vs_temperature_change.png)

*図5: 2×2、4×4、8×8の60点における配置距離と絶対温度場L2差。pooled Pearson相関は0.944である。*

![matched masterの配置](../plots/for_paper/01b_placement_resolution/matched_master_density_and_layouts.png)

*図6: 同一masterのブロック平均と容量補正後の実配置。masterは同じでも、配置生成解像度によってTSV座標は変化する。*

![matched masterのFVM温度場](../plots/for_paper/01b_placement_resolution/matched_master_fvm_temperatures.png)

*図7: 同一master・共通カラースケールによるFVM温度場比較。*

### 5.4 ROM予備結果

| 配置解像度 | train / holdout | PODモード | 平均L2 [%] | 平均上昇量L2 [%] | 平均Tmax誤差 [K] | 軸別train範囲内 | train入力との完全重複 |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 2×2 | 16 / 4 | 13 | 0.02143 | 0.1718 | 0.00682 | 4/4 | 1/4 |
| 4×4 | 16 / 4 | 15 | 0.07903 | 0.6362 | 0.02353 | 1/4 | 0/4 |
| 8×8 | 16 / 4 | 15 | 0.10266 | 0.8250 | 0.03221 | 0/4 | 0/4 |
| 16×16 | 16 / 4 | 15 | 0.11065 | 0.8913 | 0.03944 | 0/4 | 0/4 |

![実験1B ROM精度](../plots/for_paper/01b_placement_resolution/rom_accuracy_vs_placement_resolution.png)

*図8: holdout 4件のROM結果。×は各特徴量がtrainのmin–max外、星は粗視化後の入力がtrainと完全一致したケースを示す。*

### 5.5 考察

- 配置生成解像度が粗いほど16×16参照からの平均配置距離と平均温度場差が増えた。ただしmasterごとには例外があり、Chamfer距離の単調関係は19/20、温度場L2差は18/20 masterで成立した。
- `r=0.944`は強い記述相関だが、解像度群の違いと同一masterの反復をまとめた値である。配置距離だけの独立した因果効果や統計的有意性を示す値ではない。
- Tmax差は4×4で最小であり、温度場全体L2と局所最大温度は異なる応答を示す。
- ROM順位は確定結果ではない。8×8・16×16のholdoutは全件が軸別train範囲外であり、高次元側を16 trainで覆えていない。
- 2×2ではholdout master 18がtrain master 14と粗視化後に同一入力・同一FVM条件となり、ほぼゼロ誤差だった。この点を除いた2×2平均L2は約0.02858%であるが、残り3件だけなので順位の根拠にはしない。
- Chamfer距離は平均最近傍距離であり、一対一のTSV移動量ではない。また16×16は参照であって真値ではないため、「誤差」ではなく「差・感度」と呼ぶ。

数値表: [物理感度summary](../plots/for_paper/01b_placement_resolution/experiment_1b_physical_summary.tsv)、[物理感度ケース別](../plots/for_paper/01b_placement_resolution/experiment_1b_physical_cases.tsv)、[ROM summary](../plots/for_paper/01b_placement_resolution/experiment_1b_rom_summary.tsv)

## 6. 実験2：学習snapshot数

### 6.1 目的

学習snapshot数を増やしたとき、固定validationに対するROM精度、POD複雑度、入力範囲被覆がどのように変化するかを調べる。

### 6.2 手順

1. 既存50ケースのうちcase 1–40をtrain候補、41–50を固定validationとする。
2. train候補の先頭から `N=5,10,15,20,40` を入れ子状に選ぶ。
3. 各NでPOD、入力min–max scaler、Gaussian RBFを再構築する。
4. 自動PODではRIC閾値0.9999を使用する。
5. `epsilon=1.0`, `lambda=1e-6` を固定する。
6. snapshot数とPODモード数の効果を分けるため、全Nを4モードへ固定した対照も計算する。

### 6.3 結果

| Ntrain | 自動PODモード | 平均L2 [%] | 平均上昇量L2 [%] | 平均Tmax誤差 [K] | 固定4モードL2 [%] | 軸別train範囲内 |
|---:|---:|---:|---:|---:|---:|---:|
| 5 | 4 | 0.10004 | 0.8600 | 0.15640 | 0.10004 | 0/10 |
| 10 | 9 | 0.09323 | 0.8014 | 0.16611 | 0.09476 | 1/10 |
| 15 | 14 | 0.09080 | 0.7805 | 0.17681 | 0.09572 | 2/10 |
| 20 | 19 | 0.08812 | 0.7575 | 0.17102 | 0.09455 | 4/10 |
| 40 | 39 | **0.07933** | **0.6819** | 0.16342 | **0.09427** | 6/10 |

![実験2精度](../plots/for_paper/02_snapshot_count/experiment_2_accuracy_metrics.png)

*図9: 固定validation 10件の全点、平均、中央値。×は各特徴量がtrainのmin–max範囲外である。*

![実験2固定モード対照](../plots/for_paper/02_snapshot_count/experiment_2_auto_vs_fixed4_modes.png)

*図10: RICに基づきモード数を増やす場合と、全Nで4モードへ固定した場合の比較。*

![実験2モデル複雑度と被覆](../plots/for_paper/02_snapshot_count/experiment_2_modes_and_coverage.png)

*図11: snapshot数に伴う保持PODモード数と、validationが各特徴量のtrain範囲内に入る件数。*

### 6.4 考察

- 自動モード数ではN=5から40で平均L2が約20.7%相対改善した。
- 固定4モードでは同じ比較の改善は約5.8%であり、途中は非単調である。自動モード曲線の改善には、snapshot数だけでなく保持モード数が4から39へ増えた効果が含まれる。
- Tmax誤差は単調に改善しない。snapshot数を増やせばすべての指標が改善するとは言えない。
- N=5は代表的3ケースと通常2ケースからなるため、ランダムな5ケースの一般的挙動を表さない。
- N=40でもvalidation 4件が軸別train範囲外である。多次元分布の被覆にはさらに多くのsnapshotまたは別のサンプリング戦略が必要である。
- 旧SVD時間図は単発計測で非単調であり、RBF学習・推論時間も含まないため、本報告の性能結論には使用しない。

数値表: [実験2 summary](../plots/for_paper/02_snapshot_count/experiment_2_summary.tsv)、[validationケース別結果](../plots/for_paper/02_snapshot_count/experiment_2_holdout_cases.tsv)

## 7. 実験3：POD保持モード数

### 7.1 目的

POD保持モード数を変えたとき、温度場全体、温度上昇量、Tmaxがどのように変化するかを調べる。また、POD基底の表現不足とRBF係数補間の不足を分離する。

### 7.2 手順

1. case 1–40で39モードのPOD基底を一度構築する。
2. 先頭 `k=1,2,3,5,8,10,15,20,25,30,35,39` モードを使用する。
3. 各kでGaussian RBFを再学習する。`epsilon=1.0`, `lambda=1e-6` とする。
4. case 41–50を固定validationとして評価する。
5. 同じholdout真値を各POD部分空間へ直接射影し、POD射影下限を求める。

### 7.3 結果

| k | RIC [%] | POD–RBF L2 [%] | POD射影L2 [%] | 上昇量L2 [%] | Tmax誤差 [K] |
|---:|---:|---:|---:|---:|---:|
| 1 | 17.10 | 0.09586 | 0.09070 | 0.8241 | 0.13821 |
| 5 | 51.14 | 0.09356 | 0.08620 | 0.8043 | 0.14552 |
| 10 | 74.38 | 0.08596 | 0.07404 | 0.7389 | 0.15345 |
| 15 | 85.28 | 0.08032 | 0.06273 | 0.6905 | 0.16266 |
| 20 | 91.37 | 0.07978 | 0.05820 | 0.6858 | 0.16359 |
| 30 | 97.70 | **0.07910** | 0.05288 | **0.6800** | 0.16105 |
| 39 | 100.00 | 0.07933 | **0.04821** | 0.6819 | 0.16342 |

全条件中の最小平均Tmax誤差は2モードの `0.13281 K` だった。

![実験3精度](../plots/for_paper/03_pod_modes/experiment_3_accuracy_metrics.png)

*図12: PODモード数に対する固定validation全点、平均、中央値。*

![実験3誤差分解](../plots/for_paper/03_pod_modes/experiment_3_projection_vs_rbf.png)

*図13: POD–RBF全体誤差とPOD射影下限。曲線間の隔たりは、係数補間による追加誤差が存在することを示す。*

![実験3SVDとRIC](../plots/for_paper/03_pod_modes/experiment_3_svd_and_ric.png)

*図14: train snapshotの特異値減衰と、評価したモード数におけるRIC。*

### 7.4 考察

- k=1から39で平均L2は約17.2%相対改善したが、厳密には単調でなく、最小はk=30だった。
- POD射影誤差はk=39まで継続して改善する一方、POD–RBF誤差はk=15–20以降およそ0.079%で飽和する。
- したがって高モード域では、基底不足よりも入力からPOD係数へのRBF補間が支配的である。
- Tmaxはモード追加で改善せず、平均最小はk=2だった。高次モードが温度場L2を改善しても、最大値の補間精度を改善するとは限らない。
- 39モードは中心化した40 train snapshotの全非零ランクに相当し、train snapshot空間に対する切り捨てはほぼない。しかしholdoutのPOD射影L2は0.0482%残るため、未知場にはtrain部分空間外の成分がある。

数値表: [実験3 summary](../plots/for_paper/03_pod_modes/experiment_3_summary.tsv)、[validationケース別結果](../plots/for_paper/03_pod_modes/experiment_3_holdout_cases.tsv)

## 8. 実験4：Gaussian RBFのepsilon/lambda感度

### 8.1 目的

Gaussian RBFのshape parameter `epsilon` とridge正則化 `lambda` がROM精度へ与える影響を調べる。本実験は**異なるkernel familyの比較ではない**。

### 8.2 手順

1. case 1–40をtrain、41–50を固定validationとする。
2. PODは39モードに固定する。
3. `epsilon=[0.5,1.0,1.5,2.0,3.0]` を比較する。
4. `lambda=[1e-8,1e-6,1e-4,1e-2]` を比較する。
5. 20組合せすべてについて3誤差指標とvalidation全点を保存する。
6. 現基準を `(1.0, 1e-6)` とする。

### 8.3 代表結果

| 条件 | epsilon | lambda | 平均L2 [%] | 平均上昇量L2 [%] | 平均Tmax誤差 [K] |
|---|---:|---:|---:|---:|---:|
| 現基準 | 1.0 | 1e-6 | 0.07933 | 0.6819 | 0.16342 |
| L2最適 | 0.5 | 1e-2 | **0.07723** | **0.6641** | 0.15517 |
| 中間候補 | 1.5 | 1e-2 | 0.08858 | 0.7615 | 0.14347 |
| Tmax最適 | 2.0 | 1e-2 | 0.09478 | 0.8148 | **0.12656** |

![実験4ヒートマップ](../plots/for_paper/04_rbf_parameters/experiment_4_parameter_heatmaps.png)

*図15: 20条件の数値注釈付きヒートマップ。左から絶対温度L2、温度上昇量L2、Tmax誤差。*

![実験4Pareto](../plots/for_paper/04_rbf_parameters/experiment_4_l2_tmax_pareto.png)

*図16: 平均L2と平均Tmax誤差のトレードオフ。基準、L2最適、Tmax最適を強調した。*

![実験4ケース対応比較](../plots/for_paper/04_rbf_parameters/experiment_4_representative_case_comparison.png)

*図17: 基準、L2最適、Tmax最適を同じvalidationケースごとに接続した比較。×は各特徴量がtrainのmin–max範囲外である。*

### 8.4 考察

- 今回の範囲ではepsilonの影響が主である。lambdaはepsilon=0.5のときに1e-2へ上げると明確に改善するが、epsilonが1以上では感度が小さい。
- L2最適条件は現基準に対し、平均L2を約2.6%、平均Tmax誤差を約5.0%相対改善し、今回の平均指標では基準条件を上回る。
- Tmax最適条件は現基準に対しTmax誤差を約22.6%改善する一方、平均L2を約19.5%悪化させる。
- したがってパラメータ採用時には「温度場全体」か「ホットスポット最大値」か、主目的を先に固定する必要がある。
- validationのcase 45がTmax平均を大きく左右する。平均だけでなく中央値、最大値、ケース対応線を見る必要がある。
- 同じ10ケースをハイパーパラメータ選択に使用したため、選択後の性能をこの10件で最終評価してはならない。独立testが必要である。

全20条件: [実験4 summary](../plots/for_paper/04_rbf_parameters/experiment_4_summary.tsv)、[validationケース別結果](../plots/for_paper/04_rbf_parameters/experiment_4_holdout_cases.tsv)

## 9. 図表の採用方針

### 9.1 進捗報告で優先する図

1. 図1: 実験1Aの入力解像度とROM精度
2. 図4: 実験1Bの物理感度4パネル
3. 図5: 配置距離と温度場差の相関
4. 図10: 実験2の自動モードと固定4モード比較
5. 図13: 実験3のPOD射影誤差とRBF込み誤差
6. 図15・16: 実験4のパラメータヒートマップとPareto図

### 9.2 採用しない旧成果物

- `plots/for_paper/01_density_resolution/` の旧解像度比較
- 旧実験1を含む `summary_report/paper_overall_sensitivity_4panel.png`
- `summary_report/paper_summary_table.txt` の240×240表記
- `04_rbf_kernel/` をkernel family比較として説明すること
- 単発SVD時間だけを用いたruntime結論

これらは研究経緯として保存するが、本書の結論には使用しない。

## 10. 全実験に共通する限界

1. **最終testがない。** 実験1A・2–4のcase 41–50は比較・設定選択に使っているためvalidationである。
2. **split反復がない。** 1A・2–4は先頭40/末尾10、1Bはmaster 1–16/17–20の各一分割だけであり、splitによる結果変動を測定していない。
3. **subset反復がない。** 実験2は先頭Nの入れ子subsetだけであり、Nごとの選び方のばらつきを含まない。
4. **軸別範囲判定は弱い。** `within_train_bounds` は各特徴がtrainのmin–maxに入るかだけを判定し、凸包、最近傍距離、局所データ密度を評価しない。
5. **L2にghost cellを含む。** 原稿用には物理内部セルだけの指標も追加する必要がある。
6. **60格子と240格子が混在する。** 実験1A・2–4と1Bの絶対値を同じ条件として比較できない。
7. **科学的V&Vは未完了である。** manifest上の`success`は実行成功を表すが、残差、熱収支、mesh/tolerance収束性まで保証しない。
8. **RBFのepsilon比較と入力次元が交絡する場合がある。** 同じepsilonでも次元により距離分布が変化する。
9. **統計的推論ではない。** 表示した標準偏差や相関は記述統計であり、独立反復に基づく信頼区間ではない。

## 11. 学会原稿までに必要な追加実験

優先順は次の通りである。

1. 実験1Bを50 complete mastersへ増やし、master単位で40 train / 10 validationを確保する。
2. 全解像度で粗視化後のlayout signatureを作り、train/validation間の物理条件重複を排除またはgroup splitする。
3. 実験2の各Nについて複数の決定的seedでtrain subsetを組み替え、subset間の中央値・範囲を示す。
4. モデル・PODモード・RBF設定を固定した後、設定選択に一度も使っていない独立testを評価する。
5. 物理内部セルだけの絶対温度L2、温度上昇量L2、Tmax誤差、局所誤差95/99 percentileを保存する。
6. FVM runごとに残差、反復回数、有限性、熱収支、実TSV座標、layout hash、格子、config/code hashを保存する。
7. 論文用代表条件について240×240格子で再検証し、必要ならmesh/tolerance studyを行う。
8. 計算時間を評価する場合は、POD、RBF学習、オンライン推論を分離し、warm-up後に複数回計測する。

## 12. 再生成方法と成果物

FVMを再実行せず、保存済み結果から図表を再生成する。

```bash
julia --project=H2-rom evaluate_density_resolution_1a.jl
julia --project=H2-rom evaluate_density_resolution_1b.jl
julia --project=H2-rom evaluate_rom_experiments_2_to_4.jl
```

主なコード:

- [`evaluate_density_resolution_1a.jl`](../evaluate_density_resolution_1a.jl)
- [`evaluate_density_resolution_1b.jl`](../evaluate_density_resolution_1b.jl)
- [`evaluate_rom_experiments_2_to_4.jl`](../evaluate_rom_experiments_2_to_4.jl)

splitとデータ条件:

- [実験2–4 split](../plots/for_paper/experiments_2_to_4_split.tsv)
- [実験2–4 dataset metadata](../plots/for_paper/experiments_2_to_4_dataset.txt)

本報告書で「holdout」と書かれた1Bの4 masterは、現段階ではモデル選択に使用していない探索用holdoutである。一方、1A・2–4の10ケースは複数の比較に使用したため、本文では固定validationとして扱った。
