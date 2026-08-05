# ROM比較実験：プロット成果物とFVM実行方針

最終更新: 2026-08-05

## 1. この文書の役割

この文書を、TSV密度マップを用いたROM性能評価についての当面の正本とする。
会話中の提案、旧スクリプトのコメント、既存画像のタイトルが矛盾する場合は、
本書に記載した実験定義、採用条件、停止条件を優先する。

直近の期限は研究室の進捗報告、次の期限は今月末の学会原稿提出である。
したがって、明日までの成果物と、原稿までに追加する検証を分ける。

## 2. 全実験に共通する固定事項

- FVMのXY物理格子は `240 × 240` とする。
- Z方向はH2-main由来の非一様30物理セルを変更しない。
- 物理格子と密度マップ解像度は別の概念として記録する。
- TSV直径は、別途半径感度を扱わない限り40 µmとする。
- 比較する各配置のTSV総数は16本とする。
- 非収束、NaN/Inf、`242 × 242 × 32` 以外の保存配列、16本でない配置は採用しない。
- 平均値だけでなく、中央値、標準偏差または範囲、ケース別点を残す。
- 既存50件を用いる実験では、manifest先頭40件をtrain、末尾10件を固定holdoutとする。
- 現段階のholdoutは開発中のvalidationであり、学会原稿の最終testとは呼ばない。
- 絶対温度基準の相対L2だけでなく、300 Kからの温度上昇量基準L2とTmax誤差を併記する。
- 既存の画像・JLD2は上書きしない。新しい実験は1A/1B専用フォルダへ保存する。

### 評価指標

1. 絶対温度基準の相対L2誤差
2. 300 Kからの温度上昇量基準の相対L2誤差
3. 最大温度の絶対誤差 `|Tmax_ROM - Tmax_FVM|`
4. 局所絶対誤差場、および必要に応じて最大値・95/99パーセンタイル
5. POD構築、RBF学習、オンライン推論の時間
6. 保持PODモード数とROMモデルサイズ

## 3. 実験1：密度マップ解像度

旧「実験1」は、ROM入力表現と物理配置生成の影響が混在していた。
今後は実験1Aと1Bへ分離する。

### 3.1 実験1A：ROM入力表現の解像度

#### 問い

FVM形状とFVM温度場を完全に同一に保ち、ROMへ渡す空間特徴だけを
`2 × 2`、`4 × 4`、`8 × 8`、`16 × 16`へ変更したとき、ROM性能はどう変わるか。

#### 固定するもの

- 物理TSV座標
- FVM IDマップ
- FVM温度場
- train/holdoutのケースID
- POD閾値、RBF設定、評価指標

#### 変更するもの

- ROM入力ベクトルの空間解像度と次元数: 4、16、64、256

任意の固定座標は、別解像度の配置器が持つセル中央候補とは一致しない。
そのため1Aの入力は、各セルのTSV本数を全16本で割った空間ヒストグラムとする。
全解像度で特徴量の総和は1であり、FVM形状は変えない。

#### 現在のデータと結果

- 既存50ケースを使用
- train 40件、固定holdout 10件
- FVMの再実行なし
- 出力: `plots/for_paper/01a_rom_input_resolution/`

| 入力解像度 | 平均L2 | 平均Tmax誤差 | 備考 |
|---|---:|---:|---|
| 2×2 | 0.21749% | 8.50005 K | 1件の外挿が平均を支配 |
| 4×4 | 0.08635% | 0.16115 K | 現時点の最小平均L2 |
| 8×8 | 0.09344% | 0.15169 K | 16×16と同値 |
| 16×16 | 0.09344% | 0.15169 K | 8×8と同値 |

2×2ではcase 45がtrain範囲外となり、Tmax誤差72.12 Kの外れ値になった。
したがって平均だけで結論を出さず、全ケース点、中央値、外挿判定を図へ表示する。
8×8と16×16が同値なのは、現行4×4配置器が作る座標集合に対し、両表現の
距離情報が実質的に同じになっている可能性がある。一般的な解像度不要論にはしない。

#### 明日までの必須図

1. `accuracy_vs_input_resolution.png`
   - L2とTmaxの上下または左右2パネル
   - 平均、中央値、holdout全点、外挿ケースを表示
2. `same_geometry_input_encodings.png`
   - 同一物理配置と4解像度の入力表現
3. `fixed_geometry_error_fields.png`
   - 4解像度を共通カラースケールで比較

### 3.2 実験1B：配置生成解像度

#### 問い

同じ16×16基礎密度場から粗視化し、各解像度でTSVを再配置したとき、
物理形状とFVM温度場がどの程度変化するか。その上で、解像度別ROM性能がどう変わるか。

#### 入力生成規則

1. 16×16のbinary master occupancyから16セルを選び、TSV総数を16本とする。
2. `2 × 2`、`4 × 4`、`8 × 8`へブロック集約し、各粗セルのTSV本数を得る。
3. 単純ブロック平均を証拠として保存する。
4. 配置器へ渡す値は `セル内TSV本数 / その解像度のセル収容数` とする。
5. 配置展開後に、セル別本数と総数16本が一致することをFVM前に確認する。

容量補正が必要なのは、現在の配置器の総候補数が2×2・4×4では400、
8×8・16×16では256であり、単純平均をそのまま渡すとTSV本数が変わるためである。
「単純平均」と「FVMへ渡す配置密度」の両方を保存し、変換を隠さない。

#### 比較するもの

- 16×16配置を基準にした対称Chamfer距離
- 同一master内のFVM温度場相対L2差
- 同一master内のTmax差
- 共通カラースケールのFVM温度場
- 十分なcomplete masterが得られた場合のROM holdout誤差

#### データ分割

- master IDは全解像度で共通とする。
- master単位でtrain/holdoutへ分割し、同一masterが両方へ入ることを禁止する。
- 10 complete master未満ではROM比較を作らず、物理感度の予備結果だけを示す。
- 20 complete masterではtrain 16 / holdout 4となり、依然として予備評価と表示する。
- 学会原稿向けの目標は50 complete master、train 40 / validation 10である。

#### 明日までの必須図

1. `matched_master_density_and_layouts.png`
   - 1つのmasterについて、ブロック平均と実配置を4解像度で表示
2. `matched_master_fvm_temperatures.png`
   - 同一masterのFVM温度場を共通カラースケールで表示
3. `physical_sensitivity_vs_resolution.png`
   - 配置距離とFVM温度場差
4. `geometry_vs_temperature_change.png`
   - 配置変化量と温度場変化量の対応
5. 10 complete master以上なら `rom_accuracy_vs_placement_resolution.png`

#### 保存先

- FVM・config・ログ・manifest: `data/work/experiment_1b/`
- 図と表: `plots/for_paper/01b_placement_resolution/`
- 実行: `run_density_resolution_1b.jl`
- 評価: `evaluate_density_resolution_1b.jl`

## 4. 実験2：学習snapshot数

### 問い

学習snapshot数を5、10、15、20、40と増やしたとき、ROM精度とコストはどう変わるか。

### 現時点の解釈

- 絶対温度基準L2は、0.1000%から0.0793%へ改善している。
- Tmax誤差は約0.156、0.166、0.177、0.171、0.163 Kで単調ではない。
- 「snapshotを増やすと全指標が改善する」とは結論しない。
- 現行結果は先頭N件を1回選んだだけであり、選び方のばらつきを含まない。

### 明日までの必須図

1. snapshot数対L2・温度上昇量L2・Tmax誤差
2. 固定holdout全ケース点と平均・中央値・ばらつき
3. snapshot数対保持PODモード数

### 原稿までの追加

- train 40件から、各Nについて複数の決定的seedで部分集合を組み替える。
- 固定holdout 10件は変更しない。
- POD/RBF構築時間は反復計測し、中央値と範囲を示す。
- オンライン推論時間とモデルサイズを分離して示す。

## 5. 実験3：POD保持モード数

### 問い

PODモード数を変えたとき、温度場全体、最大温度、計算量がどう変化するか。

### 現時点の解釈

- 1モードから39モードで絶対温度基準L2は0.0959%から0.0793%へ改善する。
- Tmax誤差は単調改善せず、39モードで約0.163 Kである。
- POD表現力の不足と、RBF係数補間の不足を分離しないと原因を判断できない。

### 明日までの必須図

1. モード数対L2・温度上昇量L2・Tmax誤差
2. RICとholdout評価誤差の対応
3. POD射影誤差とRBF補間込み誤差の分解
4. holdoutケース別点

### 原稿までの追加

- モード数対推論時間、モデルサイズ
- 平均だけでなく最大ケース誤差

## 6. 実験4：Gaussian RBFハイパーパラメータ

フォルダ名 `04_rbf_kernel` は実験内容と一致しない。現状はkernel比較ではなく、
Gaussian RBFのshape parameter `epsilon` と正則化 `lambda` の感度解析である。

### 現時点の結果

- 最小平均L2: epsilon=0.5、lambda=1e-2、0.0772%
- 最小平均Tmax誤差: epsilon=2.0、lambda=1e-2、0.1266 K
- 現基準 epsilon=1.0、lambda=1e-6: 0.0793%、0.163 K
- L2最適とTmax最適は異なるため、採用指標を先に決める。

### 明日までの必須図・表

1. 数値注釈付きL2ヒートマップ
2. 数値注釈付きTmaxヒートマップ
3. L2対TmaxのPareto散布図
4. 全組み合わせのTSV表
5. 現基準、L2最適、Tmax最適を明示

異なるkernelの比較は別実験とし、明日の必須範囲には含めない。

## 7. 既存成果物の採用可否

### 採用しない

- `plots/for_paper/01_density_resolution/accuracy_vs_density_res.png`
- `plots/for_paper/01_density_resolution/runtime_vs_density_res.png`
- `plots/for_paper/01_density_resolution/density_resolution_real_fvm_data.txt`
- 旧実験1を含む `plots/for_paper/summary_report/paper_overall_sensitivity_4panel.png`

理由は、同じ16次元入力を解像度名だけ変えて使用した系列、人工温度場の系列、
または再描画時に新しい乱数muとcached FVMを誤って組み合わせた系列が混在するためである。

### LEGACY_UNVERIFIEDとしてのみ参照する

- `plots/for_paper/01_density_resolution/` の旧実FVM画像と6 train / 2 validationの数値

旧数値は研究経緯を示す予備結果としては残すが、新しい1A/1Bの結論には混ぜない。

### 現在採用可能

- 実験1Aの新出力
- 既存50件の重複監査結果
  - 50物理配置がすべて一意
  - 50温度場がすべて一意
  - train 40 / holdout 10間に配置・温度場の重複なし
- 実験2〜4の保存snapshotから再計算した結果。ただし新しい図ではsplitと指標を明記する。

## 8. 残り時間のFVM実行順

FVMは必ずmaster単位の4解像度一組で追加し、解像度ごとの件数を不均衡にしない。

1. **P0: master 1を完了**
   - 一様配置の4解像度
   - 実行系、保存、評価図のend-to-end確認
2. **P1: master 2〜3を完了**
   - 中央集中、四隅集中
   - 代表的な物理感度を確保
3. **P2: 10 complete masterまで追加**
   - 物理感度のケース間ばらつき
   - 最小限のROM予備比較が可能
4. **P3: 20 complete masterまで追加**
   - 16 train / 4 holdoutの予備ROM評価
5. **原稿向け: 50 complete master**
   - 40 train / 10 validation
   - 今日の時間枠を超える場合は後続runとして継続

現時点の実測は1 FVMあたり約207〜213秒である。4解像度一組は約14分、
20 complete masterは約4.7時間が目安である。次の一組を完了できる残り時間が
見込めない場合、新しいmasterを開始しない。

## 9. 停止条件

次の場合は当該ケースを不採用とし、原因確認まで次のmasterへ進まない。

- solver logに `Converged at` がない
- Juliaプロセスが非0で終了
- snapshotが存在しない、またはJLD2として読めない
- 温度場にNaN/Infがある
- 保存形状が `242 × 242 × 32` でない
- 予定セル別本数と実配置が一致しない
- TSV総数が16本でない
- 同一masterの途中でconfig規則が変わった

FVM中断後は `data/work/experiment_1b/manifest.json` を正本として再開し、
成功済みケースを再計算しない。

## 10. 明日までの最終成果物

進捗報告では、次を最小構成とする。

1. 実験1A: 固定形状での入力解像度対L2・Tmax
2. 実験1B: 同一masterの密度場・配置・FVM温度場と物理感度
3. 実験2: snapshot数対L2・Tmax
4. 実験3: PODモード数対L2・Tmax・RIC
5. 実験4: 注釈付きRBF感度またはPareto図
6. 各図の下に、train/holdout件数、指標定義、予備評価か最終評価かを記載

統合4パネルを作る場合は、新しい有効な図だけから再構成する。
旧 `paper_overall_sensitivity_4panel.png` は流用しない。
