# Implementation Plan

> 本計画は実装と決定的なソフトウェア試験を対象とする。benchmark、snapshot生成、pilot、xy二格子FVM、full探索、代表点FVM再評価は科学的数値実験であり、それぞれ別の承認済みwork-orderなしには実行しない。

- [ ] 1. 共通契約と実行前提を整備する
- [x] 1.1 物理条件と単位の明示契約を実装する
  - 境界条件、発熱、材料、幾何、TSV直径、最小pitch、格子、配置規則を必須入力として扱う。
  - 40 µmの現行条件と将来の10 µm直径を区別し、暗黙の既定値や単位不明値を拒否する。
  - 完了時、契約の保存・読込fixtureが全項目と単位を欠落なくround-tripできる。
  - _Requirements: 1.1, 1.6, 1.8_

- [x] 1.2 候補と成果物のcontent identityを実装する
  - case、layout、実配置、格子、材料場、熱伝導率場、目的定義、runの安定したhashを生成する。
  - 同じ入力から同じIDを生成し、いずれか一項目が異なる入力を別IDとして扱う。
  - 完了時、同一性fixtureが再現性と不一致検出の両方を確認できる。
  - _Requirements: 1.7, 2.4, 3.9, 14.5_

- [x] 1.3 数値policyと外部承認recordの照合を実装する
  - 解析誤差、solver残差、energy収支の基準をversion付きpolicyとして保持する。
  - 承認済みrecordのIDとhashを照合し、Boolean値だけでは承認済みにしない。
  - 完了時、未承認またはhash不一致のpolicyでは後段callbackが一度も呼ばれない。
  - _Requirements: 4.8, 4.9, 14.7_

- [x] 1.4 schema versionと旧成果物の隔離を実装する
  - finalized artifactを上書きしないversion dispatchとimmutable run境界を設ける。
  - 旧snapshot、旧目的値、旧探索結果を`LEGACY_UNVERIFIED`として読み取り専用にする。
  - 完了時、旧成果物を新datasetへ品質昇格しようとすると明示的に拒否される。
  - _Requirements: 5.12, 14.6, 14.8_

- [ ] 2. FVM物理基盤を整備する
- [ ] 2.1 (P) 物理セル間の内部面コンダクタンスを実装する
  - 二つの物理セルに限定して直列熱抵抗式を評価し、非正または非有限入力を拒否する。
  - 等幅同材、等幅異材、非対称異材を独立計算値と比較する。
  - 完了時、全fixtureが承認済み許容誤差内で一致する。
  - _Requirements: 3.2, 3.3, 4.6, 4.7_
  - _Boundary: ThermalOperators Conductance_

- [ ] 2.2 (P) 整数TSV配置のcanonical展開を実装する
  - 16成分、各0以上9以下、固定または可変総数のcountsを再scaleせず実座標へ展開する。
  - 領域、有限性、直径、80 µm最小pitch、生成本数、cell内tieを検証する。
  - 完了時、同じcountsから同じ座標とsignatureが得られ、違反入力は配置生成前に拒否される。
  - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.7_
  - _Boundary: IntegerLayout_

- [ ] 2.3 現行の外部境界熱流を一元化する
  - 外向きを正としてDirichlet、Neumann、現行Robin離散化の熱流率を扱う。
  - x、y、zの正負6面について符号と重複しない集計を検証する。
  - 完了時、既存境界fixtureの係数と熱流率を変更せず再現できる。
  - _Requirements: 1.6, 4.6_

- [ ] 2.4 エネルギー収支とsolver品質結果を実装する
  - 体積発熱、流入境界、流出境界から無次元energy不均衡を計算する。
  - 収束状態、最終残差、energy判定、policy IDを一つの品質結果として返す。
  - 完了時、収束または収支が不合格のfixtureは`PASS`にならない。
  - _Requirements: 4.8, 4.9_

- [ ] 2.5 FVM内部面係数を共有演算子へ統合する
  - 全solver kernelの物理セル間係数を共通の直列抵抗評価へ接続する。
  - 外部境界は内部面helperへ渡さず、現行境界離散化を維持する。
  - 完了時、solverが使用する全内部面係数が同じfixtureの共有演算子値と一致する。
  - _Requirements: 3.2, 3.3, 4.6, 4.7_

- [ ] 2.6 品質・物理identity付きsnapshot契約を実装する
  - 温度、材料、熱伝導率、格子、候補identity、数値品質をversion付きで保存する。
  - 読込時にshape、単位、各signatureと品質状態を再検証する。
  - 完了時、正常snapshotはround-tripし、不一致または不合格snapshotはdataset昇格を拒否される。
  - _Requirements: 1.6, 4.8, 14.5_

- [ ] 3. 共通目的評価器を実装する
- [ ] 3.1 全物理セルの最高温度評価を実装する
  - FVM場とROM場を同じphysical-cell viewへ変換し、全物理セルを走査する。
  - ghostと数値境界セルを除外し、値、単位、最大cell index、物理座標を返す。
  - 完了時、局所最大を含むfixtureで部分評価との差を検出し、欠損・非有限・shape不一致を拒否する。
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [ ] 3.2 面熱流束から材料側面勾配を計算する
  - 共有内部面係数で向き付き熱流束を求め、対象cell側の熱伝導率で勾配へ換算する。
  - 材料ID 2・7とシリコン物性の一致を検証し、内部異材面を含める。
  - 完了時、外部境界依存cellを除外し、mask空・不正幾何・signature不一致をfallbackなしで拒否する。
  - _Requirements: 3.1, 3.2, 3.3, 3.5, 3.7, 3.8, 3.9, 3.11_

- [ ] 3.3 セル中心勾配と`gmax`を再構成する
  - 正負両面の勾配を同一軸方向へ揃え、面距離で線形再構成する。
  - 三成分ノルムの全対象cell最大を求め、位置、材料ID、三成分を保存する。
  - 完了時、解析勾配fixtureで成分、ノルム、最大位置が期待値と一致する。
  - _Requirements: 3.4, 3.6, 3.10_

- [ ] 3.4 目的評価器の解析検証suiteを実装する
  - 定数場、xyz線形場、非一様z格子の層内線形場を検証する。
  - 同一物性・異なる材料IDと、二材料一次元定常熱伝導場を検証する。
  - 完了時、全fixtureが承認済み絶対・相対許容誤差内で通り、失敗時は後段へ進まない。
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

- [ ] 4. 配置dataset計画を実装する
- [ ] 4.1 通常配置の標本化と整数射影を実装する
  - 指定範囲の対数一様alphaと対称Dirichlet分布から比率を生成する。
  - 制約付き二乗誤差最小のbounded DP射影と辞書順tieを実装する。
  - 完了時、小規模全列挙fixtureと最適値・tie結果が一致する。
  - _Requirements: 5.1, 5.2_

- [ ] 4.2 444通常配置のsplit計画とauditを実装する
  - train、validation、test、6水準interpolation-testを指定件数で構成する。
  - split別RNG、seed、生成順序を保存し、snapshot、layout、実配置の重複を検査する。
  - 完了時、300・42・42・60件の計444件と全split非重複をmanifestで確認できる。
  - _Requirements: 5.3, 5.4, 5.5, 5.6, 5.12_

- [ ] 4.3 21件のlayout stress計画を実装する
  - 7規則を本数36、48、60へ適用し、承認済みscoreとtieを使用する。
  - bounded k-best DPで有限候補列を作り、既出signatureを除く上位候補を選ぶ。
  - 完了時、21件が総数・上限・実配置制約・signature一意性を満たすかfail closedになる。
  - _Requirements: 5.8, 5.9, 5.10_

- [ ] 4.4 layout OOD診断を実装する
  - countsを総数で正規化し、train配置までの最小Euclidean距離を計算する。
  - validation距離の95 percentileをversion付きで凍結する。
  - 完了時、OOD値と閾値超過を返すが、候補の自動採否には使用しない。
  - _Requirements: 5.11_

- [ ] 5. Dataset計画とFVM結果の実行境界を接続する
- [ ] 5.1 承認済みdataset計画から候補別FVM requestを生成する
  - 各caseを検証済み実配置と物理契約へ結び付け、候補固有requestを構成する。
  - policy承認、重複audit、全identityの一致をsolver呼出し前に検証する。
  - 完了時、未承認policy、重複またはidentity不一致ではsolver callbackが一度も呼ばれない。
  - _Depends: 2.2, 2.6, 4.2, 4.3_
  - _Requirements: 1.5, 1.6, 4.8, 4.9, 5.6, 5.12_

- [ ] 5.2 品質合格snapshotだけをdataset manifestへ昇格する
  - caseごとの数値品質とsignatureを検査してSnapshotRecordを確定する。
  - 通常444件とstress 21件のcompleteness、由来、content hashを集約する。
  - 完了時、不合格caseを含むdatasetはfinalizeされず、ROM trainerへ渡らない。
  - _Requirements: 4.8, 5.5, 5.8, 5.12_

- [ ] 6. ROM bundleと妥当性判定を実装する
- [ ] 6.1 候補固有の材料・熱伝導率場factoryを実装する
  - canonical countsから候補固有の材料場と熱伝導率場を生成する。
  - 物理契約、layout、材料場、熱伝導率場のsignatureを検証する。
  - 完了時、同じcountsと物理契約から同じfield signatureが得られる。
  - _Requirements: 1.7, 3.7, 3.9_

- [ ] 6.2 train-only全場POD-RBF bundleを実装する
  - POD基底、平均場、scaler、RBF写像をtrain splitだけから構築する。
  - 候補の全温度場を再構成し、候補固有物理場と共通目的評価器へ渡す。
  - 完了時、partial-cell評価を使わず、bundleのdataset・grid・physics identityが一致する場合だけ目的値を返す。
  - _Requirements: 2.1, 2.3, 5.7, 8.5_

- [ ] 6.3 validation-onlyのROM設定選択を実装する
  - 本数別・目的別の正規化MAE最大値を最小化し、承認済みtieを適用する。
  - testとstressのcase IDが設定選択へ流入しないことを検査する。
  - 完了時、hyperparameter候補集合の承認がなければtrainer callbackが呼ばれない。
  - _Requirements: 5.7, 14.7_

- [ ] 6.4 ROMの値精度と順位指標を実装する
  - split、本数、目的別にMAE、RMSE、最大絶対誤差、Spearman、設計幅正規化誤差を求める。
  - 幅0、定数順位、標本不足、非有限値を`INCONCLUSIVE`にする。
  - 完了時、testと6水準interpolation-testの閾値判定を表形式で取得できる。
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.10_

- [ ] 6.5 経験的誤差幅とstress診断を実装する
  - 学習本数、6 interpolation水準、その他中間本数の誤差幅規則を分ける。
  - stress単点比、分母不定、参考Spearmanを計算し、適用外を`UNSUPPORTED`にする。
  - 完了時、目的・本数ごとの誤差幅とstress状態を再現可能に保存できる。
  - _Requirements: 6.5, 6.6, 6.7, 6.8_

- [ ] 6.6 ROM validation gateを集約する
  - 必須split、本数、目的、stress状態を一つの理由付きgateへ集約する。
  - `PASS`以外を合格扱いせず、再学習・領域制限・FVM優先評価の選択肢を返す。
  - 完了時、`FAIL`、`INCONCLUSIVE`、`UNSUPPORTED`の各fixtureで探索callbackが一度も呼ばれない。
  - _Requirements: 6.9_

- [ ] 7. 整数NSGA-II探索器を実装する
- [ ] 7.1 非支配rank、crowding distance、tournamentを実装する
  - 2目的と3目的の有限値に対して非支配sortを行う。
  - 端点、設計幅0、rank・crowding・signature tieを決定的に扱う。
  - 完了時、手計算fixtureのrank、距離、勝者と一致する。
  - _Requirements: 8.1, 9.1_

- [ ] 7.2 固定本数の遺伝演算子を実装する
  - 二点交叉、親平均に基づく決定的repair、1本移送mutationを実装する。
  - 承認済み発火率と乱数消費順を守り、各cellの0以上9以下を保証する。
  - 完了時、全offspringが36、48、60の指定総数を厳密に保存する。
  - _Requirements: 8.2, 8.3, 8.4, 10.3, 10.5_

- [ ] 7.3 可変本数の初期化と遺伝演算子を実装する
  - 本数の整数一様標本化後に通常配置分布から初期個体を生成する。
  - 交叉、追加、除去、移送、決定的repairまたは棄却を実装する。
  - 完了時、評価される全offspringが総数36以上60以下かつ各cell 0以上9以下になる。
  - _Requirements: 9.2, 9.3, 9.4, 9.5, 10.3, 10.5_

- [ ] 7.4 評価cacheと論理evaluation ledgerを実装する
  - model、目的定義、格子、物理契約、材料場、熱伝導率場、layoutの全signatureをcache keyに含める。
  - method、phase、problem、seed別に一意な未cache評価を数える。
  - 完了時、cache hitと実行不能棄却が論理評価予算へ加算されない。
  - _Requirements: 8.6, 9.8, 11.4, 11.5_

- [ ] 7.5 全履歴archiveとdomain診断を実装する
  - 各世代frontと全評価履歴の一意な非劣解archiveを区別する。
  - 本数範囲、学習水準・内挿、layout OOD、counts、目的値、seedを保存する。
  - 完了時、OOD候補を自動棄却せずarchiveとledgerから追跡できる。
  - _Requirements: 8.7, 9.6, 9.7, 9.8_

- [ ] 7.6 2目的・3目的のgeneration loopを統合する
  - 共通のrank、演算子、候補評価、cache、archiveを世代更新へ接続する。
  - 実行不能候補をpenalty個体としてpopulationへ残さない。
  - 完了時、同じconfigとseedから候補列、各世代front、最終archiveが一致する。
  - _Requirements: 8.1, 8.5, 8.7, 9.1, 9.8, 10.5_

- [ ] 8. 比較分析と代表点選定を実装する
- [ ] 8.1 同予算random baselineを実装する
  - NSGA-IIと同じ通常配置分布、実行可能性、pilot/full seed indexを使用する。
  - 各論理runでNSGA-IIの一意未cache評価数と同数へ到達するまで生成する。
  - 完了時、方式間で物理cacheを共有しても両ledgerが独立し、同じtarget budgetを記録する。
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7_

- [ ] 8.2 pilot由来の正規化範囲を凍結する
  - 問題ごとにpilot NSGA-IIとbaselineの目的値unionから最小・最大を求める。
  - 設計幅0を`INCONCLUSIVE`にし、凍結後はclipや事後更新を行わない。
  - 完了時、同じpilot artifactから同じ正規化IDと範囲が得られる。
  - _Requirements: 10.8, 10.12, 10.13_

- [ ] 8.3 2次元・3次元hypervolumeを実装する
  - 正規化済み非劣集合に対して参照点1.1の厳密計算を行う。
  - 参照点条件を破る値があれば点数と目的を記録して`INCONCLUSIVE`にする。
  - 完了時、既知の2D・3D fixtureと一致し、seed別値を集約可能になる。
  - _Requirements: 10.9, 10.14_

- [ ] 8.4 kneeとarc-length fallbackを実装する
  - 両端線分への最大垂直距離で2目的kneeを選ぶ。
  - 非劣点不足、端点重複、曲率不明時にarc-length中点と承認済みtieを使う。
  - 完了時、degenerate fixtureで「明瞭なkneeなし」と決定的候補が返る。
  - _Requirements: 10.10, 10.11_

- [ ] 8.5 xy二格子検証専用の12配置planを実装する
  - 2目的pilotのNSGA-II archiveだけから各本数の両端点とkneeの9 layoutを選ぶ。
  - 重複時はmaximinで補い、各本数3 layout未満ならfail closedにし、一様3配置を加える。
  - 完了時、baselineや本検証30 slotと異なるphase IDで12配置planが凍結される。
  - _Depends: 7.6, 8.4_
  - _Requirements: 7.1_

- [ ] 8.6 2目的の18 selection slotを実装する
  - 方式・固定本数ごとに両端点とkneeを選び、重複をmaximinで補う。
  - OOD値とsignatureのtieを適用し、支配された候補では補充しない。
  - 完了時、FVM結果を見る前に18 slotが凍結され、一意候補不足なら失敗する。
  - _Requirements: 12.1, 12.2, 12.4, 12.5, 12.6, 12.7_

- [ ] 8.7 3目的の12 selection slotを実装する
  - 各方式で三目的の未選択極値を選んだ後、maximinで各6 slotまで補う。
  - 承認済み極値tieと距離tieを適用し、layout重複をslotとsolveで区別する。
  - 完了時、FVM結果を見る前に12 slotが凍結され、一意候補不足なら失敗する。
  - _Requirements: 12.1, 12.3, 12.4, 12.5, 12.6, 12.7_

- [ ] 8.8 ROMとFVMの照合判定を実装する
  - layout signatureで目的値、OOD、支配関係を対応付ける。
  - 目的差が経験的誤差幅内なら識別不能とし、改善符号と主要支配反転を検出する。
  - 完了時、反転fixtureでは結論を確定せずROM妥当性再検討状態を返す。
  - _Requirements: 12.8, 12.9, 12.11, 12.13_

- [ ] 9. 段階実行と承認gateを実装する
- [ ] 9.1 workflow状態機械と承認停止点を実装する
  - 各stageでapproval record、artifact hash、必須quality gateを照合する。
  - `PASS`以外は`STOPPED`へ遷移し、同じrun IDで後段を再開しない。
  - 完了時、未承認または非PASSの各fixtureで該当stage callbackが一度も呼ばれない。
  - _Requirements: 4.8, 6.9, 7.6, 10.2, 10.4, 10.6, 10.7, 14.7_

- [ ] 9.2 全場throughput benchmark計測器を実装する
  - 200候補について全場再構成、物理場生成、全cell目的評価を逐次計測する。
  - wall time、候補毎秒、peak memory、内訳、保守見積りと観測見積りを返す。
  - 完了時、`ROM_VERIFIED`かつbenchmark個別承認がなければ計測callbackが呼ばれない。
  - _Requirements: 6.10, 10.6, 10.7_

- [ ] 9.3 pilotとfullのimmutable設定・seed計画を実装する
  - pilotの100個体・100世代・3 seedとfull初期値の200個体・300世代・10 seedを別phase identityにする。
  - 用途別乱数streamを明示し、設定変更を新しいconfig IDとapprovalへ結び付ける。
  - 完了時、同じ設定・seedから初期集団と遺伝操作が再現される。
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [ ] 9.4 pilot探索launcherを承認gateへ接続する
  - ROM gate合格とbenchmark結果・所要時間承認後だけpilotを起動可能にする。
  - 2目的、3目的と対応する同予算baselineを同じpilot phaseへ束縛する。
  - 完了時、pilot結果manifestが確定するまで二格子検証へ遷移しない。
  - _Requirements: 10.1, 10.3, 10.5, 10.6, 11.3, 14.7_

- [ ] 9.5 xy二格子感度・順位安定性の評価器を実装する
  - 専用12配置planについて同一物理配置の240格子と480格子をpairingする。
  - 固定本数別の両目的誤差比、改善符号、順位、支配関係を判定する。
  - 完了時、幅0・閾値不合格・反転を非PASSとし、「3次元格子独立性」と表示しない。
  - _Depends: 8.5_
  - _Requirements: 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_

- [ ] 9.6 full探索launcherを承認gateへ接続する
  - pilot完了、二格子gate合格、full個別承認を全て起動条件にする。
  - pilot後の設定変更は理由・計算量影響を持つ新configと再承認だけを受理する。
  - 完了時、三条件のいずれかが欠ければfull探索callbackが一度も呼ばれない。
  - _Requirements: 7.6, 10.2, 10.4, 14.7_

- [ ] 9.7 物理cacheと論理run予算をrun coordinatorへ統合する
  - 物理評価を再利用してもmethod、phase、problem、seed別ledgerを独立に保つ。
  - run manifest確定時にunique評価数、cache hit、棄却数、全artifact IDを固定する。
  - 完了時、共有cache fixtureでも各runの論理予算が期待値と一致する。
  - _Requirements: 8.6, 9.8, 11.4, 11.5, 14.5_

- [ ] 9.8 代表点FVM再評価launcherを実装する
  - `FULL_COMPLETE`、凍結済み30 slot plan、代表点FVM個別承認を起動条件にする。
  - layout signature重複を除く一意solve requestを作り、品質・identity合格結果だけを各slotへ再対応付けする。
  - 完了時、未承認・未凍結・品質不合格ではsolverまたはreport callbackが呼ばれず、30 slot数と一意solve数が別々に記録される。
  - _Depends: 8.6, 8.7, 9.6_
  - _Requirements: 4.8, 12.7, 12.8, 12.11, 12.12, 14.7_

- [ ] 10. 相関・可視化・報告を実装する
- [ ] 10.1 集合別の目的相関診断を実装する
  - 通常testを本数別主要診断、stressを参考診断、非劣集合を条件付き診断として分ける。
  - Spearmanの符号を保持し、定数や標本不足を`INCONCLUSIVE`にする。
  - 完了時、相関だけから目的の採否を自動決定しない解釈付き表が得られる。
  - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6_

- [ ] 10.2 結果表とprovenance出力を実装する
  - candidate、run、dataset、model、split、grid、探索予算、品質、FVM状態を追跡可能にする。
  - seed別hypervolumeとmedian/IQR、30 slot数と一意solve数、legacy状態を別列で出力する。
  - 完了時、任意の図表点を元のcandidate ledgerと全content IDへ辿れる。
  - _Requirements: 11.7, 12.8, 14.5, 14.6, 14.7, 14.8_

- [ ] 10.3 2目的・3目的の可視化を実装する
  - 2目的の単位付き散布図で本数、方式、ROM/FVM、支配状態を識別する。
  - 3目的の3D散布図と、全三組の2D散布図を同じledgerから生成する。
  - 完了時、図と同じ点集合・属性を持つdata表が同時に保存される。
  - _Requirements: 14.1, 14.2, 14.3_

- [ ] 10.4 研究主張の表示境界を実装する
  - 「近似パレート集合」または「得られた非劣解候補」だけを使用する。
  - FVM主張を`FVM_VERIFIED`のselection slotに限定し、経験的誤差幅を保証と表現しない。
  - 完了時、真のfront、大域最適、3D格子独立、未検証FVM主張の禁止表現検査が通る。
  - _Requirements: 7.7, 12.10, 12.12, 12.13, 14.4_

- [ ] 11. 境界間の統合検証を行う
- [ ] 11.1 FVM演算子からsnapshotまでの統合契約を検証する
  - solver内部面、外部境界、energy、snapshot round-tripを小さいfixtureで接続する。
  - signature不一致、未収束、収支不合格のfailure pathを検証する。
  - 完了時、正常fixtureだけが品質合格snapshotになり、異常fixtureは後段停止する。
  - _Requirements: 1.5, 1.6, 3.9, 4.6, 4.7, 4.8, 4.9_

- [ ] 11.2 dataset計画からmanifest確定までを統合検証する
  - 承認済み計画、mock FVM、品質判定、snapshot昇格を接続する。
  - 444通常配置と21 stress配置の件数、重複、legacy混入failureを検証する。
  - 完了時、全case合格時だけ確定dataset manifestが生成される。
  - _Requirements: 4.8, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10, 5.11, 5.12_

- [ ] 11.3 datasetからROM validation gateまでを統合検証する
  - 確定manifest、train-only ROM、validation選択、test・interpolation・stress評価を接続する。
  - test/stress漏洩と各非PASS状態の停止経路を検証する。
  - 完了時、全必須判定が`PASS`の場合だけ`ROM_VERIFIED`へ遷移する。
  - _Requirements: 5.7, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9_

- [ ] 11.4 NSGA-IIとbaselineの再現性・同予算を統合検証する
  - 固定・可変探索、cache、ledger、archive、baselineを決定的fixtureで接続する。
  - 同じseedの候補列・archive hashと、方式別target budget一致を検証する。
  - 完了時、2目的・3目的の双方で違反候補が評価されず、同予算比較が成立する。
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 10.1, 10.3, 10.5, 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7_

- [ ] 11.5 正規化・指標・選定planの凍結を統合検証する
  - pilot artifactから正規化、hypervolume、knee、二格子plan、30 slot planを接続する。
  - FVM結果後の候補差替え禁止と、二格子plan・本検証planのID分離を検証する。
  - 完了時、同じ入力artifactから同じ凍結planとhashが得られる。
  - _Requirements: 7.1, 10.8, 10.9, 10.10, 10.11, 10.12, 10.13, 10.14, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7_

- [ ] 11.6 workflowの承認・品質failure pathを統合検証する
  - 未承認benchmark、pilot、full、代表点FVMの各callback-zero経路を検証する。
  - ROM、二格子、代表点FVMの非PASS状態が後段を停止することを検証する。
  - 完了時、全stageが承認順を飛び越えず、失敗runを同じIDで再開できない。
  - _Requirements: 4.8, 6.9, 7.6, 10.2, 10.4, 10.6, 10.7, 12.11, 14.7_

- [ ] 11.7 検証済みfixtureから図表までのE2E契約を検証する
  - `FVM_VERIFIED`結果だけを性能主張へ渡し、ROMのみの点と明確に分離する。
  - 相関表、結果表、2D・3D図、図表dataの再現可能なhashを検証する。
  - 完了時、30 slot外の候補にFVM主張が付かず、legacy成果物が新しい結論へ混入しない。
  - _Requirements: 12.8, 12.9, 12.10, 12.11, 12.12, 12.13, 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7, 14.8_
