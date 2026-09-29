# Requirements Document

## Introduction

本機能は、3D-ICのTSV密度マップを対象とした単目的最適化を、物理的に整合した温度勾配評価を含む多目的最適化へ拡張する。高速探索には温度場を予測するPOD-RBF ROMを用い、NSGA-IIで得た候補をFVMで再評価する。結果は有限の評価予算と複数乱数seedから得た近似パレート集合であり、大域最適解または真のパレートフロントとは呼ばない。

本要件が本人承認された後、本specは、多目的探索、444配置の新規dataset、`gmax` 定義、ROM妥当性判定、および代表点のFVM検証について、旧 `paper-rom-pipeline` の該当要件を置き換える。旧成果物は削除せず、再検証まで `LEGACY_UNVERIFIED` として参照専用にする。

## Boundary Context

- **In scope**:
  - FVMと同じ直列熱抵抗による面コンダクタンスに整合した離散セル中心勾配指標 `gmax`
  - `Tmax` と `gmax` の2目的、および `Tmax`、`gmax`、TSV本数の3目的NSGA-II
  - 固定本数3水準と可変本数範囲に対応する実行可能な整数配置演算子
  - 配置生成分布、独立split、配置外挿stress setを含む新規ROM dataset
  - ROMの値精度、順位保存性、本数内挿、配置外挿、xy方向二格子感度の検証
  - 同一評価予算のランダム探索、両方式の代表点FVM再評価、hypervolume比較、パレート可視化
- **Out of scope**:
  - MGDA、およびε制約法を主結果または必須比較とすること
  - 大域最適性、真のパレートフロント、連続場の厳密な最大温度勾配、または3次元格子独立性の保証
  - POD-RBF以外のROM方式への無断変更
  - 将来のTSV直径10 µmに対する実験、配置ピッチまたは計算格子の決定
  - 信号TSV、配線長、機械応力、製造コストの目的関数追加
  - 本要件承認だけを根拠とした長時間FVM、snapshot生成、パイロット探索または本探索
- **Adjacent expectations**:
  - `component-generator` は4×4整数密度マップを実配置へ決定的に展開し、最小ピッチと配置制約を検証する
  - FVMソルバーは材料場、温度場、格子幾何、熱伝導率、面コンダクタンスおよびエネルギー収支を一貫して提供する
  - `research-data-contract` はsplit非重複、layout同一性、品質状態を管理する
  - `research-run-provenance` と `numerical-vv` は新規runの来歴および数値検証証拠を管理する

## Requirements

### Requirement 1: 基準問題と設計変数の固定

**Objective:** As a 研究責任者, I want 探索条件と将来条件を分離して固定したい, so that 条件の取り違えなく比較可能な多目的解析を行える

#### Acceptance Criteria

1. The system shall 現行基準問題にTSV直径40 µm、最小中心間ピッチ80 µm、FVM格子240×240×30、4×4密度マップ、および密度セル当たり最大9本を使用する
2. The system shall 設計変数を16成分の整数TSV本数ベクトルとして表現し、各成分を0以上9以下に制限する
3. When 2目的問題を構成する, the system shall 総TSV本数を36、48、60のいずれか一つへ厳密に固定し、各本数を独立した探索として扱う
4. When 3目的問題を構成する, the system shall 総TSV本数を36以上60以下の整数として扱う
5. When 密度ベクトルを実配置へ展開する, the system shall 生成座標数が総TSV本数に一致し、全座標が有限かつ領域内で、相異なるTSV中心間距離が80 µm以上であることを検証する
6. The system shall 境界条件、発熱条件、材料物性、総発熱量、幾何条件、TSV直径、最小ピッチ、格子寸法および配置規則をrun metadataへ明示し、暗黙の既定値で補完しない
7. The system shall 同じ設計入力から同じ実配置とlayout signatureを決定的に生成する
8. The system shall 将来の10 µmをTSV直径として記録し、配置ピッチまたは計算格子幅として解釈せず、本specの基準問題へ流用しない

### Requirement 2: 最高温度評価

**Objective:** As a 熱設計者, I want 候補固有の全温度場から最高温度を評価したい, so that 局所的な高温点を取りこぼさず最適化できる

#### Acceptance Criteria

1. When FVMまたはROM温度場を評価する, the objective evaluator shall 全ての物理セルを走査して `Tmax` を求める
2. The objective evaluator shall ゴーストセルおよび数値境界用セルを `Tmax` の候補から除外する
3. The objective evaluator shall 高速化を理由として一部のサンプリング点だけから `Tmax` を推定しない
4. The objective evaluator shall 温度場のshape、格子signature、layout signatureおよびcase IDが評価対象候補と一致することを検証する
5. The objective evaluator shall `Tmax` の値、単位、最大セルのインデックスおよび物理座標を記録する
6. If 温度場が欠損、非有限、shape不一致またはsignature不一致である, then the objective evaluator shall 当該評価を失敗させる

### Requirement 3: 面コンダクタンス整合の離散温度勾配評価

**Objective:** As a 熱解析研究者, I want 材料界面と不等間隔格子に整合する `gmax` を評価したい, so that TSV配置による局所温度勾配を物理的に比較できる

#### Acceptance Criteria

1. The system shall `gmax` を、固定FVM格子上で面熱流束から再構成した離散セル中心温度勾配ノルムの最大値と定義し、連続温度場の厳密な最大値とは表現しない
2. When 内部セル面 `f` のコンダクタンスを求める, the gradient evaluator shall `G_f = A_f / (d_Pf/k_P + d_Nf/k_N)` と等価な直列熱抵抗式を用いる。ただし `A_f` は面積、`d_Pf` と `d_Nf` は各セル中心から面までの正距離、`k_P` と `k_N` は面法線方向の正の熱伝導率とする
3. The gradient evaluator shall 候補固有のFVMまたはROM温度場から、FVMソルバーと同じ面コンダクタンス演算子を用いて向き付き面熱流束を計算する。対象セルPの各面では、面積で除した共有熱流束密度を対象セルの熱伝導率 `k_P` で除し、`g_{P,f}=-q_f/k_P` として同じ座標軸の正方向へ符号を揃える。面の有効熱伝導率または隣接セルの熱伝導率で代用しない
4. When セル中心の各軸成分を求める, the gradient evaluator shall 正負両側面の勾配を同一軸方向へ揃え、両面値を `g_-`,`g_+`、セル中心から各面までの距離を `d_-`,`d_+` として `g_P=(d_+ g_- + d_- g_+)/(d_-+d_+)` で線形再構成する
5. The gradient evaluator shall 前項の式を直交格子、セル内一定の正のスカラー熱伝導率、格子面に沿う材料界面、および接触熱抵抗なしの条件へ適用し、適用条件外へ暗黙に拡張しない
6. The gradient evaluator shall 各対象セルについて `sqrt(gx^2 + gy^2 + gz^2)` を計算し、その最大値を `gmax` とする
7. The gradient evaluator shall 材料ID 2および7の物理セルを評価対象とし、両IDに適用されるシリコン物性値との整合性を検証する
8. The gradient evaluator shall 内部材料界面に接する対象セルを含め、ゴーストセルまたは外部境界面に依存する中心勾配を除外する
9. The gradient evaluator shall 温度場、材料場、熱伝導率場、格子幾何、case IDおよびlayout signatureが同一候補に属することを検証する
10. The gradient evaluator shall `gmax` の値、単位、最大セルのインデックス、物理座標、材料IDおよび3成分を記録する
11. If 評価対象maskが空、入力が欠損または非有限、距離・面積・熱伝導率が非正、shapeまたはsignatureが不一致である, then the gradient evaluator shall runを失敗させ、別の差分式へ暗黙にフォールバックしない

### Requirement 4: 目的評価器の決定的検証

**Objective:** As a 数値解析品質保証担当者, I want `Tmax` と `gmax` の実装を解析可能な場で検証したい, so that 最適化前に符号、距離、材料界面処理の誤りを検出できる

#### Acceptance Criteria

1. When 定数温度場を入力する, the gradient evaluator shall 許容誤差内で全対象セルの勾配を0と評価する
2. When 一様物性の線形温度場を入力する, the gradient evaluator shall 指定した解析勾配の各成分およびノルムを再現する
3. When 非一様z格子上の層内線形温度場を入力する, the gradient evaluator shall 格子間隔の違いに依存せず解析勾配を再現する
4. When 同一物性で材料IDだけが異なる隣接セルを入力する, the gradient evaluator shall 人工的な勾配不連続を生成しない
5. When 二材料一次元定常熱伝導場を入力する, the gradient evaluator shall 界面熱流束の連続性と各材料側の解析温度勾配を再現する
6. The test suite shall objective evaluatorが再利用する面コンダクタンスとFVMソルバーの値が同一入力で一致することを検証する
7. The test suite shall 異なる熱伝導率および異なる両側半幅を持つ面について、実装値を直列熱抵抗式から独立に計算した期待値と比較する
8. If 独立な面コンダクタンス検証、FVM収束判定またはエネルギー収支判定が失敗する, then the workflow shall ROM dataset生成へ進まずFVM側の修正へ戻る
9. Before ROM dataset生成, the design workflow shall 各解析検証の絶対・相対許容誤差、FVM収束基準およびエネルギー収支基準を `numerical-vv` 契約に基づいて提示し、研究責任者の承認後に凍結する

### Requirement 5: 配置生成、datasetおよびsplit契約

**Objective:** As a ROM研究者, I want 固定本数内の多様な配置と未学習条件を分離したデータを使用したい, so that 配置内補間、本数内挿、配置外挿を区別して評価できる

#### Acceptance Criteria

1. When 通常配置を生成する, the data pipeline shall `u ~ Uniform(-0.7, 1.0)`、`alpha = 10^u` とし、16セルの対称Dirichlet分布 `Dirichlet(alpha,...,alpha)` から比率を標本化する
2. The data pipeline shall Dirichlet標本比率 `p_i` を、`sum_i (n_i-N p_i)^2` を最小化する整数ベクトルへ射影する。ただし `sum_i n_i=N`、`0<=n_i<=9` とし、複数解はセルindexの辞書順で決定する
3. The data pipeline shall TSV本数36、48、60について各100配置をtrain、各14配置をvalidation、各14配置をtestへ割り当てる
4. The data pipeline shall 未学習TSV本数39、42、45、51、54、57について各10配置を独立したinterpolation-testへ割り当てる
5. The data pipeline shall 基準datasetをtrain 300、validation 42、test 42、interpolation-test 60の合計444配置として構成する
6. The data pipeline shall splitごとに独立した乱数seedと生成順序を記録し、通常datasetの全split間、および通常datasetとstress setの間におけるsnapshot ID、layout signatureまたは実配置の重複をfail closedで拒否する
7. The ROM trainer shall trainだけからPOD基底、平均場、scalerおよびRBF写像を学習し、validationだけをhyperparameter選択へ使用する
8. The data pipeline shall 一様、発熱比例、高発熱優先greedy、低発熱優先greedy、中心集中、周辺・隅集中、checkerboardの7規則を本数36、48、60へ適用した21配置をlayout stress setとして生成する
9. The data pipeline shall 各stress規則について規則score順の候補列を構成し、既出signatureを除く最上位候補を選んで総数、上限9、実配置制約および21件のsignature一意性を満たす。規則scoreと同点時の辞書順はdesignで提示しdataset生成前に承認を得る
10. The data pipeline shall stress setを学習、hyperparameter選択または通常testの合格値調整へ使用せず、配置外挿検証だけに使用する
11. The data pipeline shall layoutを `p=x/N` で正規化し、train配置までの最小Euclidean距離をOOD診断値とする。通常validation配置の同距離分布における95 percentileを暫定閾値として凍結し、閾値超過を自動棄却ではなくFVM代表点選定時のtie-breakと報告にだけ用いる
12. The data pipeline shall `LEGACY_UNVERIFIED` のsnapshotまたは旧目的値を新しい検証済みdatasetへ混入させない

### Requirement 6: ROMの精度、順位保存性および適用範囲

**Objective:** As a 最適化利用者, I want ROMがFVMの値と設計順位を適用範囲内で保存することを確認したい, so that 高速探索で有望候補を失わない

#### Acceptance Criteria

1. The validator shall `Tmax` と `gmax` のそれぞれについてMAE、RMSE、最大絶対誤差、Spearman順位相関をsplit別、本数別および目的別に報告する
2. The validator shall 各集合・目的 `f` について `MAE(ROM,FVM)/(max(FVM)-min(FVM))` を設計幅正規化誤差として計算する
3. If FVM設計幅が0または数値的に判別不能、順位が定数、標本数不足または相関が非有限である, then the validator shall 当該判定を合格とせず `INCONCLUSIVE` とする
4. The validator shall testの本数36、48、60それぞれ、およびinterpolation-testの本数39、42、45、51、54、57それぞれについて、両目的の正規化誤差0.2未満およびSpearman順位相関0.9以上を要求する
5. The validator shall 本数・目的ごとの経験的絶対誤差幅 `E_f,N` を、通常testと該当本数stress setにおける最大絶対残差の大きい方として固定する
6. The validator shall interpolation-test対象の6水準では該当本数の最大絶対残差を用い、それ以外の未学習中間本数では6水準全体における目的別最大絶対残差を保守的な経験的誤差幅として用いる
7. The validator shall stress setの各配置について `abs(ROM-FVM)/(max(FVM_test,N)-min(FVM_test,N))` を報告し、いずれかが0.2以上または分母が判別不能なら当該領域をunsupportedとする
8. The validator shall stress setのSpearman相関を参考値として報告し、少数かつ構成的なstress配置の相関だけで合否を決めない
9. If 必須の本数、目的またはsplitが不合格または `INCONCLUSIVE`、あるいはstress setのいずれかの配置が `unsupported` である, then the optimization pipeline shall 本探索を停止し、再学習、探索領域制限または該当候補のFVM優先評価を研究責任者へ提示する
10. The validator shall 計算時間または評価スループットと順位保存性の両方を報告し、順位相関だけを高速化の証拠として扱わない

### Requirement 7: xy方向二格子感度と順位安定性

**Objective:** As a 数値解析品質保証担当者, I want 目的値のxy格子感度を確認したい, so that 240×240格子固有の順位を物理解として誤認しない

#### Acceptance Criteria

1. When 2目的パイロット探索が完了する, the verifier shall 本数36、48、60の各探索から `Tmax` 端点、`gmax` 端点およびRequirement 10のkneeを1 selection slotずつ選ぶ。slot内のlayout重複時はRequirement 12.4のmaximin補充を適用し、各本数の非劣解archiveに一意な3 layoutがなければRequirement 12.6と同様にfail closedとする
2. The verifier shall 9代表配置に加えて本数36、48、60の一様基準配置3件を用い、合計12配置を同一物理条件、同一実TSV配置、同一z方向30層の240×240×30格子と480×480×30格子で評価する
3. The verifier shall 固定本数ごとの3点および各目的 `f` について `MAE(f_240,f_480)/(max(f_480)-min(f_480))` をxy二格子誤差比として計算し、異なるTSV本数を同じ設計幅へ混合しない
4. If 480格子での設計幅が0または数値的に判別不能である, then the verifier shall 当該判定を合格とせず `INCONCLUSIVE` とする
5. The verifier shall 各固定本数で両目的のxy二格子誤差比がそれぞれ0.2未満であることを要求し、同じ本数の一様配置を基準とする改善符号、および同じ本数の代表3点間の順位と支配関係も報告する
6. If 誤差比が不合格または `INCONCLUSIVE`、あるいは改善符号または主要な支配関係が反転する, then the workflow shall 本探索または研究主張を停止して研究責任者へ返す
7. The reporter shall この検証を「xy方向二格子感度・順位安定性」と表記し、z方向収束、収束次数または3次元格子独立性の証明とは表現しない

### Requirement 8: 2目的NSGA-II探索

**Objective:** As a 熱設計者, I want 固定TSV本数ごとの温度と温度勾配の非劣解候補を得たい, so that 本数を揃えた公平な配置比較を行える

#### Acceptance Criteria

1. The optimizer shall `Tmax` と `gmax` をともに最小化し、非支配rankとcrowding distanceを用いるbinary tournament選択のNSGA-IIを使用する
2. The optimizer shall TSV本数36、48、60について独立した3系列を実行し、系列内で総TSV本数を不変に保つ
3. The optimizer shall 整数密度ベクトル用交叉とセル間TSV移送突然変異を用い、各セル0以上9以下および固定総数を満たす子だけを評価する
4. The optimizer shall 制約違反へのpenaltyだけに依存せず、決定的修復によって実行可能性を保証する
5. The optimizer shall 全個体の候補固有ROM温度場からRequirement 2および3と同じ評価器を用いて両目的を計算する
6. The optimizer shall layout signatureによる評価cacheを用い、重複候補を新規評価回数へ数えない
7. The optimizer shall 各世代の非劣解集合に加えて全評価履歴の一意な候補から比較用非劣解archiveを構築し、目的値、整数密度ベクトル、実配置signature、seedおよび一意な評価回数を記録する

### Requirement 9: 3目的NSGA-II探索

**Objective:** As a 熱設計者, I want 熱性能とTSV本数を同時に比較したい, so that 追加TSVの効果とコストを重み付けなしで評価できる

#### Acceptance Criteria

1. The optimizer shall `Tmax`、`gmax`、総TSV本数を全て最小化するNSGA-IIを使用する
2. The optimizer shall 総TSV本数36以上60以下かつ各セル0以上9以下の整数密度ベクトルだけを評価する
3. When 初期集団を生成する, the optimizer shall 総TSV本数を36以上60以下の整数一様分布から選び、その本数を条件としてRequirement 5の通常配置分布からlayoutを生成する
4. The optimizer shall 整数密度ベクトル用交叉と、TSVの追加、除去およびセル間移送突然変異を用いる
5. When 演算後に制約違反が生じる, the optimizer shall 決定的修復を行うか子を棄却し、違反個体を目的評価しない
6. The optimizer shall train本数範囲内であること、本数方向では内挿か学習水準か、およびlayout OOD診断を別々に記録する
7. When layout OODの候補を検出する, the optimizer shall 自動的に有効または無効と断定せず、Requirement 12の同点時だけFVM選定を優先する
8. The optimizer shall layout signatureによる評価cacheを用い、各世代の非劣解集合に加えて全評価履歴の一意な候補から比較用非劣解archiveを構築し、3目的値、整数密度ベクトル、seedおよび一意な評価回数を記録する

### Requirement 10: 探索予算、演算子、比較指標および再現性

**Objective:** As a 研究評価者, I want 探索予算と比較条件を事前固定したい, so that NSGA-IIの性能を再現可能かつ公平に評価できる

#### Acceptance Criteria

1. When パイロット探索を実行する, the optimizer shall 個体数100、100世代、独立3 seedを使用する
2. When パイロット結果と計算時間が確認され本探索が別途承認される, the optimizer shall 個体数200、300世代、独立10 seedを初期設定として使用する
3. Before パイロットを実行する, the design workflow shall 交叉率、突然変異率、演算子の詳細および修復tie-breakを提示し、研究責任者の明示承認を得る
4. If パイロット後に本探索設定を変更する, then the workflow shall 理由、計算量への影響および変更値の再承認を得る
5. The optimizer shall 用途別seedを明示し、同じ設定とseedから初期集団および遺伝操作を再現可能にする
6. Before パイロットを実行する, the workflow shall 100以上1000以下の候補を用いた全場再構成・全物理セル目的評価のthroughput benchmarkを実施し、パイロット、本探索およびbaselineの所要時間を外挿して承認を得る
7. If 所要時間が許容されない, then the workflow shall 停止して方針確認へ戻り、部分セル評価、scalar ROM、予算削減またはbatch方式へ無断変更しない
8. The evaluator shall 2目的では固定本数36、48、60の問題ごと、3目的では3目的問題全体について、パイロットのNSGA-IIとランダム探索を合わせた目的値範囲で各目的を正規化し、その範囲を本探索前に凍結する
9. The evaluator shall 凍結後の正規化空間でhypervolume参照点を各軸1.1に固定し、hypervolumeを主要比較指標としてseed別およびmedian/IQRで報告する
10. When 2目的kneeを選ぶ, the evaluator shall 正規化非劣解の両端を結ぶ線分への垂直距離が最大の点を決定的に選ぶ
11. If 一意な非劣解点が3未満、端点が重複、または曲率が判別不能である, then the evaluator shall 正規化非劣解列の累積arc length中点に最も近い既評価候補を代替代表点とし「明瞭なkneeなし」と表示する。同距離はlayout OOD診断値の降順、layout signatureの順で決定する
12. If パイロット正規化の設計幅が0または数値的に判別不能である, then the evaluator shall 当該hypervolume比較を `INCONCLUSIVE` とする
13. The evaluator shall 本探索の正規化値を `[0,1]` へ切り詰めず、凍結した参照点を事後変更しない
14. If 本探索の非劣解archiveに少なくとも1目的の正規化値が1.1を超える点が存在する, then the evaluator shall 該当点数と目的を報告し、参照点が全対象点より劣るという条件を満たさないため当該問題のhypervolume比較を `INCONCLUSIVE` とする

### Requirement 11: 同予算ランダムbaseline

**Objective:** As a 研究評価者, I want 同じ候補生成範囲と評価予算のランダム探索を比較したい, so that NSGA-IIの探索上の利点を過大評価しない

#### Acceptance Criteria

1. The baseline shall NSGA-II初期集団と同じ通常配置生成分布および実行可能性制約を使用する
2. When 3目的baselineを生成する, the baseline shall まず総TSV本数を36以上60以下の整数一様分布から選び、その本数を条件としてlayoutを生成する
3. The baseline shall NSGA-IIと同じpilot 3 seed、本探索10 seedを使用し、方式固有の乱数streamを対応するseed indexでpairingして集計する
4. The evaluator shall pilotまたは本探索、2目的の各固定本数または3目的問題、およびseedの組合せごとに、NSGA-IIが固定世代終了までに行った初期集団を含む一意かつ未cacheの実行可能ROM評価数を確定し、baselineを同数へ到達するまで生成する
5. The evaluator shall 評価予算を方式・phase・問題・seedごとの論理run内で独立に集計し、方式間またはseed間で物理的な計算cacheを再利用しても予算を共有しない。各run内の重複cache hitおよび実行不可能として棄却した候補は評価予算へ数えない
6. The baseline shall 全評価履歴から非劣解archiveを構築し、NSGA-IIの比較用非劣解archiveと同じ正規化、参照点、seed集約およびhypervolumeを用いる
7. The evaluator shall 最良seedだけで比較せず、seed別結果およびmedian/IQRを報告する

### Requirement 12: 代表点のFVM再評価と経験的誤差幅

**Objective:** As a 研究責任者, I want NSGA-IIとbaselineの代表候補を同じ規則でFVM確認したい, so that ROM上の優劣を過大評価しない

#### Acceptance Criteria

1. The verifier shall 問題および方式ごとに全seedの一意候補を統合して支配関係を再計算し、全履歴非劣解archiveから代表点を選ぶ
2. The verifier shall 2目的の各方式・各固定本数から `Tmax` 端点、`gmax` 端点およびRequirement 10のkneeを選び、NSGA-II 9点とbaseline 9点を240×240×30 FVMで再評価する
3. The verifier shall 3目的の各方式について `Tmax`、`gmax`、TSV本数の順に未選択の極値を最大3点選び、その後、正規化目的空間で既選択点からの最小距離を最大化する未選択点を1点ずつ反復選択して合計6 selection slotを満たし、NSGA-II 6 slotとbaseline 6 slotを再評価する
4. The verifier shall layout signatureが異なる候補だけを数え、極値、端点またはkneeが重複するときは残りのarchiveからmaximin規則で必要数まで補充する
5. The verifier shall 極値tieを他目的の正規化値、layout OOD診断値の降順、layout signatureの順で決定し、maximin距離tieをlayout OOD診断値の降順、layout signatureの順で決定する
6. If 非劣解archiveだけでは各方式・問題に必要な一意layout数を満たせない, then the verifier shall 支配された候補で補充せず代表点選定をfail closedとする
7. The verifier shall 2目的18 slotと3目的12 slotの合計30 selection slotをROM目的値、layout OOD診断値およびsignatureからFVM実行前に決定し、FVM結果を見た後の差し替えを禁止する。異なる方式または問題のslotに同一layout signatureが現れた場合は同一条件のFVM結果を再利用し、30 slotと実際の一意FVM solve数を別々に報告する
8. The verifier shall ROMとFVMの `Tmax`、`gmax`、支配関係、layout signatureおよびOOD診断を対応付けて報告する
9. When ROMだけで候補AとBを比較する, the reporter shall 目的 `f` の差が `E_f,N(A)+E_f,N(B)` 以下なら、その目的を「経験的誤差幅内で識別不能」と表示する
10. The reporter shall FVM再評価後の非劣解候補とROM予測だけの候補を視覚的およびデータ上で区別する
11. If FVM再評価によって改善符号または主要な支配関係が反転する, then the workflow shall 結論を確定せずROM妥当性の再検討へ戻す
12. The reporter shall FVMに基づく性能主張を30 selection slotに対応するFVM再評価済み候補へ限定し、ROM近似front全体がFVM検証済みとは表現しない
13. The reporter shall 経験的誤差幅を観測標本上の保守的診断値として扱い、未見配置に対する統計的信頼区間、厳密誤差上限または真の優劣保証とは表現しない

### Requirement 13: 目的間関係の診断

**Objective:** As a 多目的最適化研究者, I want `Tmax` と `gmax` の関係を選択偏りのない集合で確認したい, so that 目的の冗長性とトレードオフを正しく説明できる

#### Acceptance Criteria

1. The evaluator shall 通常testの独立FVM母集団について本数36、48、60ごとに `Tmax` と `gmax` のSpearman順位相関を主要診断として報告する
2. The evaluator shall stress setの相関を配置外挿に対する参考値として分離して報告する
3. The evaluator shall NSGA-II非劣解集合の相関を選択後の条件付き相関としてのみ報告し、目的母集団の相関と同一視しない
4. The evaluator shall 相関係数の符号を保持し、絶対値だけを目的採否基準に使用しない
5. The reporter shall 強い正相関を目的が冗長である可能性、強い負相関をトレードオフの可能性として解釈し、相関だけから目的の採用または棄却を自動決定しない
6. The reporter shall 相関を非劣解の広がり、FVM再評価および物理的意味と併せて報告する

### Requirement 14: 可視化、来歴および仕様の優先順位

**Objective:** As a 研究発表者, I want 非劣解集合と検証状態を一貫して可視化し追跡したい, so that 2目的と3目的の結果を再現可能に説明できる

#### Acceptance Criteria

1. The visualization shall 2目的結果を単位付き `Tmax`–`gmax` 平面に示し、本数36、48、60、探索方式、ROM予測、FVM再評価および支配状態を識別可能にする
2. The visualization shall 3目的結果について `Tmax`、`gmax`、TSV本数の3次元散布図を生成する
3. The visualization shall 3目的の全組合せである `Tmax`–`gmax`、`Tmax`–TSV本数、`gmax`–TSV本数の3枚の2次元散布図を生成する
4. The reporter shall 図表で「近似パレート集合」または「得られた非劣解候補」と表記し、「真のパレートフロント」または「大域最適解」と表記しない
5. The reporter shall run ID、dataset ID、model ID、split ID、case ID、layout signature、コードrevision、格子、TSV直径、最小ピッチ、目的定義、seed、探索予算、FVM検証状態および品質判定を追跡可能にする
6. After 本要件が本人承認された後, if `paper-rom-pipeline` の424件dataset、`|rho|<0.7` による目的選定、旧 `grad3d_max`、ε制約主探索または旧交換関係と本specが競合する, then the workflow shall 本specを優先し、旧成果物を削除せず `LEGACY_UNVERIFIED` と表示する
7. The workflow shall requirements、design、tasksおよび数値実験の各承認境界を保持し、要件承認を実装または長時間計算の許可として扱わない
8. The workflow shall 旧 `paper-rom-pipeline` Requirement 1を本spec Requirement 5、旧Requirement 2を本spec Requirement 6、旧Requirement 4を本spec Requirements 3・6・13、旧Requirement 5を本spec Requirements 5・6、旧Requirements 6・7を本spec Requirements 8–12、旧Requirement 9の多目的図を本spec Requirement 14、旧Requirement 10の多目的run来歴を本spec Requirement 14で置き換える。旧Requirements 3および8、ならびに旧Requirement 9・10の非競合部分は自動的に置き換えない
