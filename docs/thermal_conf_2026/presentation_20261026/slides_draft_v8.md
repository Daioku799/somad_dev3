---
marp: true
math: mathjax
theme: default
paginate: true
size: 16:9
title: TSV密度マップを用いた縮約モデルによる3D-ICの熱設計最適化の研究
author: 大屋 蒼真
footer: 熱工学コンファレンス2026 / B11 / 本編第8稿
style: |
  section {
    font-family: "Noto Sans CJK JP", "Yu Gothic", "Hiragino Sans", sans-serif;
    font-size: 27px;
    color: #25272b;
    background: #ffffff;
    padding: 48px 66px 40px;
  }
  h1 { margin: 0 0 18px; color: #741b47; font-size: 47px; line-height: 1.16; }
  h2 { color: #741b47; font-size: 31px; }
  p { margin: 10px 0; line-height: 1.45; }
  li { margin: 7px 0; }
  strong { color: #a13d22; }
  blockquote {
    margin: 15px 0;
    padding: 9px 17px;
    border-left: 7px solid #741b47;
    background: #f6edf2;
    font-size: 28px;
    line-height: 1.35;
  }
  blockquote p { margin: 0; }
  small { color: #59616b; font-size: 17px; line-height: 1.35; }
  img { max-height: 475px; }
  .lead { background: linear-gradient(150deg, #741b47 0 43%, #ffffff 43% 100%); }
  .lead h1 { color: white; font-size: 47px; width: 75%; }
  .lead h3 { color: white; }
  .flow { display:flex; align-items:center; justify-content:center; gap:10px; margin:22px 0; }
  .node { min-width:155px; padding:17px 12px; border:2px solid #741b47; border-radius:10px; background:white; text-align:center; font-size:23px; }
  .node.accent { background:#f6edf2; }
  .arrow { color:#68707a; font-size:35px; }
  mjx-container[display="true"] { font-size: 28px; margin: 2px 0 !important; }
  .compact-flow { margin: 4px 0; }
  .compact-flow .node { min-width: 205px; padding: 10px 11px; font-size: 21px; }
  .panel-row { display:flex; align-items:flex-end; justify-content:center; gap:18px; margin:6px 0 2px; }
  .panel-row img { display:block; }
  .panel-density { height:300px; }
  .panel-xy { height:215px; }
  .panel-yz { height:150px; }
  .eq-row { display:flex; align-items:center; justify-content:center; gap:28px; }
  .eq-legend { padding: 6px 14px; border-left: 4px solid #741b47; background: #f7f7f8; font-size: 19px; line-height: 1.5; }
  .eq-legend p { margin: 0; }
  .eq-legend mjx-container { font-size: 19px; }
  .compact-metrics { margin: 2px 0 6px; }
  .compact-metrics .metric { padding: 4px 12px; }
  .compact-metrics .metric strong { font-size: 31px; }
  .metric-row { display:flex; justify-content:center; gap:22px; margin:18px 0; }
  .metric { min-width:220px; padding:15px 12px; border:2px solid #741b47; border-radius:10px; background:white; text-align:center; }
  .metric strong { font-size:39px; }
  .small { font-size:20px; }
  .split-row { display:flex; justify-content:center; gap:16px; margin:17px 0; }
  .split { width:230px; padding:14px 9px; border-radius:9px; text-align:center; background:#f3f4f6; border-top:7px solid #741b47; }
  .split strong { font-size:36px; color:#741b47; }
  .two-col { display:grid; grid-template-columns:1fr 1fr; gap:30px; align-items:center; }
  .map-pair { display:flex; gap:25px; justify-content:center; align-items:start; }
  .map-title { text-align:center; font-weight:700; margin-bottom:7px; }
  .density-grid { display:grid; grid-template-columns:repeat(4,49px); grid-template-rows:repeat(4,49px); gap:3px; }
  .cell { display:flex; align-items:center; justify-content:center; font-weight:700; border:1px solid #d7dbe0; }
  .d0 { background:#f7fbff; color:#333; } .d1 { background:#deebf7; color:#333; }
  .d3 { background:#9ecae1; color:#222; } .d4 { background:#6baed6; color:white; }
  .d8 { background:#2171b5; color:white; } .d9 { background:#084594; color:white; }
  .result { padding:13px 18px; border-left:7px solid #a13d22; background:#fff1eb; font-size:23px; line-height:1.5; }
  .summary { flex:1; min-height:125px; padding:17px 14px; border-radius:10px; background:white; border-top:7px solid #741b47; text-align:center; }
  .method-note { padding:10px 16px; background:#f7f7f8; border-left:5px solid #741b47; font-size:21px; line-height:1.4; }
  .plot-caption { text-align:center; font-size:20px; color:#59616b; margin-top:0; }
---

<!-- _class: lead -->
<!-- _footer: "" -->

# TSV密度マップを用いた縮約モデルによる<br>3D-ICの熱設計最適化の研究

### 大屋 蒼真・小野 謙二（九州大学）

<div style="margin-top:210px;font-size:25px;">熱工学コンファレンス2026　B11</div>

<!--
目安 0:20。
3D-ICの熱設計において、多数のTSV配置を高速に比較するための仕組みを検討しました。
本日は、その考え方と、ROMによる予測およびFVMでの確認結果を報告します。
-->

---

# 3D-ICの熱問題

![bg right:36% contain](intro_3dic_thermal_v4.png)

ICの積層により、さらなる**高密度化・高性能化**を図ります。

<div style="text-align:center;font-size:42px;color:#741b47;">↓</div>

高密度化によって高温部が生じ、**動作不良の原因**となります。

> **設計によって最高温度を抑える工夫が必要です。**

<small>右：3D-ICの熱問題を示す生成概念図。今回の解析モデルや解析結果そのものではありません。</small>

<!--
目安 0:50。
ICを積層することにより、平面方向だけでなく垂直方向にも素子を配置でき、さらなる高密度化と高性能化を図れます。
一方、高密度化によって高温部が生じると、動作不良の原因となります。
そのため、設計によって最高温度を抑える工夫が必要です。
-->

---

# 設計初期における配置評価

![bg right:38% vertical contain](../figures/3d_ic.jpg)
![bg contain](model_xy_v5.png)

層を貫通するTSV（through-silicon via）は、信号経路に加えて**チップ内の熱輸送**にも影響します。

TSV配置を設計パラメータとすると、膨大なパターンの配置をシミュレーションしなければなりません。

> **本研究：TSV密度マップを入力とする縮約モデル（ROM）で低温配置の候補を選び、FVMで確認しました。**

<div class="result">結果：FVMでも、同じTSV本数の一様配置より最高温度が<strong>1.12〜1.38 K</strong>低い候補を得ました。</div>

<small>右上：3D-ICとTSVの概念図（出典：NIST, “3D stacked integrated circuit”, nist.gov/image/3dicjpg）／右下：本研究モデルのXY材料分布</small>

<!--
目安 1:00。
層を貫通するTSVは信号経路として使われますが、同時にチップ内の熱輸送にも影響します。
このTSV配置を設計パラメータとして扱うと、評価すべき配置パターンは膨大になります。
そこで本研究では、TSV密度マップを入力とする縮約モデル、ROMで温度を高速に予測し、低温になる配置の候補を選んで、FVMで確認しました。
結果として、FVMでも同じ本数の一様配置より1.12から1.38ケルビン低温な候補が得られました。
以下、ROM、密度マップ、ROMの構築と精度、配置探索、FVMでの確認の順に説明します。
-->

---

# 縮約モデル（ROM）

複数のFVM温度場から、温度分布の変化を表す**主要な空間パターン**をPOD（固有直交分解）で抽出します。

<div class="flow compact-flow">
  <div class="node">複数の<br>FVM温度場</div><div class="arrow">→</div>
  <div class="node accent">PODによる<br>パターン抽出</div><div class="arrow">→</div>
  <div class="node">主要な<br>空間パターン</div>
</div>

未知配置の温度場は、各パターンに係数を掛けて**重ね合わせる**ことで近似します。

<div class="eq-row" style="margin-top:22px;">
<div class="eq-main">

$$
T(\mathbf{x};\boldsymbol{\mu}) \approx \overline{T}(\mathbf{x}) + \sum_{j=1}^{r} a_j(\boldsymbol{\mu})\,\phi_j(\mathbf{x})
$$

</div>
<div class="eq-legend">

$\mathbf{x}$：位置　$\boldsymbol{\mu}$：TSV配置（密度マップ）
$T$：温度場　$\overline{T}$：平均温度場
$\phi_j$：$j$番目の空間パターン
$a_j$：パターン$j$の係数　$r$：パターン数

</div>
</div>

<div class="metric-row compact-metrics">
  <div class="metric"><strong>1,728,000</strong><br><span class="small">個の温度値</span></div>
  <div class="arrow">→</div>
  <div class="metric"><strong>24</strong><br><span class="small">個の係数</span></div>
</div>

<!--
目安 1:05。
複数のFVM温度場から、温度分布の変化を表す主要な空間パターンをPODで抽出します。
未知配置の温度場は、平均温度場に各パターンを係数付きで重ね合わせることで近似します。
本研究ではパターン数を24とし、約173万個の温度値を24個の係数で表します。
次に、TSV配置をROMへ入力する方法を説明します。
-->

---

# TSV密度マップ

個々のTSV座標を入力すると、TSV本数に応じて入力が増加します。そこで、TSV実装領域を4×4に分割し、各セルのTSV本数をROMへの入力としました。

<div class="panel-row" style="margin-top:22px;">
  <img class="panel-density" src="density_map_random_N48_v6.png">
  <img class="panel-xy" src="material_xy_random_N48_v6.png">
  <img class="panel-yz" src="material_yz_random_N48_v6.png">
</div>

<div class="flow compact-flow">
  <div class="node">TSV座標<br><em>N</em>本 × (<em>x</em>, <em>y</em>) ＝ 2<em>N</em>個</div><div class="arrow">→</div>
  <div class="node">4×4セルごとに<br>本数を集計</div><div class="arrow">→</div>
  <div class="node accent">密度マップ<br>16個（<em>N</em>によらず一定）</div>
</div>

<!--
目安 0:55。
個々のTSV座標をそのまま設計変数にすると、TSV本数とともに入力が増え、学習と探索が難しくなります。
そこでTSV実装領域を4掛ける4に分け、各セルのTSV本数を固定長16成分の密度マップとして表しました。
左が48本のランダム配置の密度マップ、中央と右がそこから展開した実際のTSV配置です。
この16個がROMの入力になります。
-->

---

# ROMの構築方法

> **密度マップ16成分から三次元温度場を予測するPOD–RBF ROMを、300配置のFVM温度場で構築しました。**

<div class="split-row" style="align-items:center;margin:12px 0;">
  <div class="split" style="width:190px;"><strong>100</strong><br>N=36</div>
  <div class="split" style="width:190px;"><strong>100</strong><br>N=48</div>
  <div class="split" style="width:190px;"><strong>100</strong><br>N=60</div>
  <div class="arrow">→</div>
  <div class="node accent">POD基底<br>24モード</div>
</div>

<div class="flow compact-flow" style="margin-top:14px;">
  <div class="node"><strong>入力</strong><br>密度マップ16成分</div><div class="arrow">→</div>
  <div class="node">RBF補間で<br>係数24個を推定</div><div class="arrow">→</div>
  <div class="node">POD基底の<br>重ね合わせ</div><div class="arrow">→</div>
  <div class="node accent"><strong>出力</strong><br>三次元温度場</div>
</div>

<div class="method-note" style="margin-top:14px;">RBF補間：学習配置との密度マップの近さに応じて係数を補間します。<br>24モードとRBF条件は、構築用とは別の<strong>モデル選定42配置</strong>で決定しました。</div>

<p class="small" style="margin-top:6px;">解析条件：3層モデル／総発熱量0.384 W／上面対流・側面下面断熱／FVM 240×240×30セル／3層共通TSV配置</p>

<!--
目安 1:00。
前のスライドの16成分の密度マップから、三次元温度場を予測するROMを作ります。
まず、TSV本数36、48、60の各100配置、合計300配置のFVM温度場から、POD基底を24モード求めました。
予測では、密度マップを入力として、学習配置との密度マップの近さに応じたRBF補間で24個の係数を推定し、POD基底を重ね合わせて三次元温度場を出力します。
これをPOD–RBF ROMと呼びます。
モード数とRBFの条件は、構築用とは別の42配置で選定しました。
ここまでは構築方法であり、次に独立したデータで精度を確認します。
-->

---

# ROMの精度検証結果

<div class="two-col" style="grid-template-columns:1.18fr 0.82fr;gap:20px;">
  <div>
    <img src="rom_accuracy_independent_v8.png" style="width:690px;max-height:500px;">
  </div>
  <div>
    <div class="result" style="margin-bottom:14px;">ROM構築・モデル選定に使用していない<br><strong>独立評価42配置</strong></div>
    <div class="metric" style="margin:10px auto;"><strong>0.0950 K</strong><br><span class="small">最高温度MAE</span></div>
    <div class="metric" style="margin:10px auto;"><strong>0.493%</strong><br><span class="small">温度場相対L2誤差</span><br><span class="small" style="color:#59616b;">300 Kからの温度上昇基準</span></div>
  </div>
</div>

<!--
目安 0:55。
ROM構築とモデル選定に使用していない独立評価42配置で、FVMとROMの最高温度を比較しました。
点が破線に近いほど両者が一致しています。
最高温度の平均絶対誤差は0.0950ケルビン、温度上昇基準の温度場相対L2誤差は0.493パーセントでした。
このROMを配置探索へ使用します。
-->

---

# 最高温度を目的とした配置探索

各TSV本数を固定し、ROMが予測する最高温度を目的とする<br>**マルチスタート離散局所探索**を行いました。

<div class="flow compact-flow" style="margin-top:26px;">
  <div class="node">初期配置</div><div class="arrow">→</div>
  <div class="node">TSVを1本<br>別セルへ移動</div><div class="arrow">→</div>
  <div class="node accent">最大240近傍を<br>ROMで評価</div><div class="arrow">→</div>
  <div class="node">最も低温な<br>配置へ更新</div><div class="arrow">↺</div>
</div>

<div class="metric-row" style="margin-top:34px;">
  <div class="metric"><strong>25</strong><br><span class="small">本数水準<br>N=36〜60</span></div>
  <div class="metric"><strong>400</strong><br><span class="small">初期配置／各N</span></div>
  <div class="metric"><strong>1</strong><br><span class="small">近傍で移動する<br>TSV本数</span></div>
</div>

<p class="small">改善する近傍がなくなるまで反復し、各Nの400初期配置から得た候補のうち、ROMが予測する最高温度が最も低い配置を選びました。</p>

<!--
目安 0:55。
目的関数はROMが予測する最高温度です。
TSV本数は一回の探索中では固定し、36本から60本までの25水準を別々に探索しました。
一つのTSVを別のセルへ移す最大240近傍を評価し、最も温度が下がる配置へ更新します。
これを改善がなくなるまで繰り返し、各本数について400個の初期配置から得た中で最も低温な候補を選びました。
-->

---

# TSV本数と最高温度の近似トレードオフ

各TSV本数で得た低温候補と、同じ本数の一様配置を比較しました。

<div style="text-align:center;margin-top:3px;">
  <img src="tmax_vs_count_v8.png" style="width:1040px;max-height:470px;">
</div>

<div class="plot-caption">四角・丸の線：ROM予測値（N=36〜60）　　三角・星：FVM確認値（N=36、48、60）</div>

> **同じTSV本数でも、配置探索によって一様配置より低温な候補が得られました。**

<div class="plot-caption">本数別の局所探索で得た候補を並べたもので、大域最適解や真のパレートフロントではありません。</div>

<!--
目安 0:55。
横軸がTSV本数、縦軸が最高温度です。
灰色の四角が一様配置、青の丸が各本数で探索された低温候補で、どちらもROM予測値です。
本数を増やすほど最高温度が低下するとともに、同じ本数でも探索候補は一様配置より低温になっています。
三角と星で示した36、48、60本についてはFVMで再計算しました。
この曲線は各本数の局所探索結果を並べたもので、真のパレートフロントではありません。
-->

---

# 探索候補のFVM再検証

<div class="two-col" style="grid-template-columns:1.05fr 0.95fr;gap:24px;align-items:start;">
  <div>
    <div class="map-pair">
      <div>
        <div class="map-title">探索で得た低温候補（N=48）</div>
        <div class="density-grid">
          <div class="cell d0">0</div><div class="cell d1">1</div><div class="cell d0">0</div><div class="cell d3">3</div>
          <div class="cell d4">4</div><div class="cell d0">0</div><div class="cell d1">1</div><div class="cell d0">0</div>
          <div class="cell d9">9</div><div class="cell d9">9</div><div class="cell d8">8</div><div class="cell d0">0</div>
          <div class="cell d3">3</div><div class="cell d9">9</div><div class="cell d0">0</div><div class="cell d1">1</div>
        </div>
      </div>
      <div>
        <div class="map-title">一様配置（N=48）</div>
        <div class="density-grid">
          <div class="cell d3">3</div><div class="cell d3">3</div><div class="cell d3">3</div><div class="cell d3">3</div>
          <div class="cell d3">3</div><div class="cell d3">3</div><div class="cell d3">3</div><div class="cell d3">3</div>
          <div class="cell d3">3</div><div class="cell d3">3</div><div class="cell d3">3</div><div class="cell d3">3</div>
          <div class="cell d3">3</div><div class="cell d3">3</div><div class="cell d3">3</div><div class="cell d3">3</div>
        </div>
      </div>
    </div>
    <div class="result" style="margin-top:22px;">
      N=48のFVM最高温度<br>
      低温候補：<strong>315.618 K</strong><br>
      一様配置：316.994 K
    </div>
  </div>
  <div style="text-align:center;">
    <img src="fvm_reduction_v8.png" style="width:500px;max-height:470px;">
  </div>
</div>

> **FVM再計算でも、一様配置より1.119〜1.376 K低温でした。**

<p class="small">数字はセルごとのTSV本数（上が+Y方向で、スライド5の密度マップと同じ向き）。固定した発熱分布と解析条件に対する低温候補です。</p>

<!--
目安 1:10。
左は48本の場合のセル別TSV本数です。
探索で得た低温候補では、一様配置とは異なりTSVが偏って配置されています。
両者をFVMで再計算すると、低温候補は315.618ケルビン、一様配置は316.994ケルビンでした。
36、48、60本の3水準では、一様配置に対する低減量はそれぞれ1.355、1.376、1.119ケルビンでした。
したがってROM上だけでなく、FVMでも候補選別の効果を確認できました。
ただし、得られたのは低温候補であり、大域最適性を保証するものではありません。
-->

---

<!-- _class: lead -->

# まとめ

> **POD–RBF ROMを、FVMで再計算すべき低温配置候補の選別に利用できました。**

<div class="flow" style="align-items:stretch;">
  <div class="summary"><strong>300配置</strong><br><span class="small">FVM温度場から<br>ROMを構築</span></div>
  <div class="summary"><strong>0.0950 K</strong><br><span class="small">独立評価の<br>最高温度MAE</span></div>
  <div class="summary"><strong>25水準</strong><br><span class="small">N=36〜60を<br>本数別に探索</span></div>
  <div class="summary"><strong>1.119–1.376 K</strong><br><span class="small">FVM確認済み<br>低減量</span></div>
</div>

**密度マップ → ROM構築・精度確認 → 本数別探索 → FVM再確認**

<p class="small">結論の範囲は、固定した非一様発熱分布、境界条件、TSV径、3層共通配置です。ROMはFVMの完全な代替ではありません。</p>

<!--
目安 0:40。累積約9:45。
まとめです。
300配置のFVM温度場からPOD–RBF ROMを構築しました。
独立評価42配置の最高温度を平均0.0950ケルビンの誤差で予測しました。
このROMを使って36本から60本までの25水準を本数別に探索しました。
選んだ候補はFVMでも一様配置より1.119から1.376ケルビン低温でした。
以上から、固定条件の範囲で、ROMをFVMで再計算すべき低温候補の選別に利用できました。
-->

---

<!-- _paginate: false -->

# 補足：構築に含めないTSV本数での精度

<div class="metric-row" style="margin-top:40px;">
  <div class="metric"><strong>40</strong><br><span class="small">配置<br>N=42、54（各20）</span></div>
  <div class="metric"><strong>0.0812 K</strong><br><span class="small">最高温度MAE</span></div>
</div>

<div class="method-note" style="margin-top:28px;">ROM構築には N=36、48、60 だけを使用しました。N=42、54は構築にもモデル選定にも使っていません。</div>

<!--
質疑用。本編では説明しない。
構築に含めていないTSV本数42、54の各20配置、計40配置で、最高温度MAEは0.0812ケルビンでした。
-->
