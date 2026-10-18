---
marp: true
math: mathjax
theme: default
paginate: true
size: 16:9
title: TSV密度マップを用いた縮約モデルによる3DIC の熱設計最適化の研究
author: 大屋 蒼真
footer: 熱工学コンファレンス2026 / B11 / 本編第10稿
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
  small { display: block; color: #59616b; font-size: 17px; line-height: 1.3; }
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
  .model-row { display:grid; grid-template-columns:1.05fr 0.95fr; gap:18px; align-items:start; }
  .model-row ul { margin:0; padding-left:1.1em; }
  .model-row .method-note { margin-top:14px; }
  .model-figs { text-align:center; }
  .model-figs img { display:block; margin:0 auto 2px; }
  img.model-xy { height:268px; margin-top:-28px !important; }
  img.model-yz { width:440px; }
  .dens-row { align-items:center; gap:22px; margin:12px 0 6px; }
  img.dens-map { height:310px; }
  img.dens-xy { height:310px; }
  .dens-arrow { text-align:center; line-height:1.1; }
  .acc-row { display:grid; grid-template-columns:1.12fr 0.88fr; gap:22px; align-items:center; }
  img.acc-plot { height:470px; }
  .acc-row ul { margin:6px 0 0; padding-left:1.1em; font-size:24px; }
  .acc-result { margin-top:18px; padding:12px 18px; border-left:7px solid #a13d22; background:#fff1eb; font-size:25px; line-height:1.6; }
  .acc-head { font-weight:700; color:#741b47; }
  .acc-note { font-size:19px; color:#59616b; line-height:1.3; }
  .trade-fig { text-align:center; margin-top:2px; }
  img.trade-plot { width:960px; }
  .plot-caption { text-align:center; font-size:20px; color:#59616b; margin-top:0; }
---

<!-- _class: lead -->
<!-- _footer: "" -->

# TSV密度マップを用いた縮約モデルによる<br>3DIC の熱設計最適化の研究

### 大屋 蒼真・小野 謙二（九州大学）

<div style="margin-top:210px;font-size:25px;">熱工学コンファレンス2026　B11</div>

<!--
目安 0:20。
3D-ICの熱設計において、多数のTSV配置を高速に比較するための仕組みを検討しました。
本日は、その考え方と、ROMによる予測およびFVMでの確認結果を報告します。
-->

---

# 3D-ICの熱問題とTSV配置

![bg right:36% vertical contain](intro_3dic_thermal_v4.png)
![bg contain](../figures/3d_ic.jpg)

ICの積層により**高密度化・高性能化**を図る一方、高温部が生じると**動作不良の原因**となります。

層を貫通するTSV（through-silicon via）は、信号経路に加えて**チップ内の熱輸送**にも影響します。

TSV配置を設計パラメータとすると、評価すべき配置は膨大になります。

> **様々なTSV配置を高速に評価し、低温な配置を探したい。**

<small>右上：3D-ICの熱問題を示す生成概念図（今回の解析モデル・解析結果そのものではありません）／右下：3D-ICとTSVの概念図（出典：NIST, “3D stacked integrated circuit”, nist.gov/image/3dicjpg）</small>

<!--
目安 0:50。
ICを積層すると、垂直方向にも素子を配置でき、さらなる高密度化と高性能化を図れます。
一方、高密度化によって高温部が生じると、動作不良の原因となります。
層を貫通するTSVは信号経路として使われますが、同時にチップ内の熱輸送にも影響します。
このTSV配置を設計パラメータとして扱うと、評価すべき配置は膨大になります。
そこで、様々なTSV配置を高速に評価し、低温な配置を探すことを目指します。
-->

---

# 本研究の流れ

膨大なTSV配置の中から低温な配置を見つけるため、次の4段階で研究を行いました。

<div class="flow compact-flow" style="margin-top:26px;align-items:stretch;">
  <div class="node"><strong>① 入力を減らす</strong><br>TSV配置を<br>16個の数で表す</div><div class="arrow" style="align-self:center;">→</div>
  <div class="node accent"><strong>② 近似モデル</strong><br>限られた数の<br>FVM計算から<br>温度場を高速に予測<br><span class="small">（別データで精度を確認）</span></div><div class="arrow" style="align-self:center;">→</div>
  <div class="node"><strong>③ 探索</strong><br>モデルで多数の<br>配置を評価し<br>低温な候補を選ぶ</div><div class="arrow" style="align-self:center;">→</div>
  <div class="node"><strong>④ 確認</strong><br>選んだ候補を<br>FVMで再計算</div>
</div>

<!--
目安 0:45。
膨大な配置の中から低温な配置を見つけるため、本研究は4つの段階で進めました。
まず、TSV配置を16個の数で表し、入力を減らします。
次に、限られた数のFVM計算から、温度場を高速に予測する近似モデル、縮約モデルを作り、別のデータで精度を確認します。
そのモデルで多数の配置を評価して低温な候補を選び、最後に選んだ候補をFVMで再計算して確認しました。
まず、解析に用いたモデルを示します。
-->

---

# 解析モデル

<div class="model-row">
<div>

- 1.2 mm角・厚さ0.6 mmの**3層積層モデル**
- 各Si層に**発熱ブロック4個**<br>総発熱量**0.384 W**
- 上面：周囲**300 K**への対流<br>側面・下面：断熱
- 中央1 mm角がTSV実装領域<br>（TSV配置は3層共通）
- FVM：240×240×30セル

<div class="method-note">黄：Cu TSV　灰：Si　赤：発熱ブロック<br>紫：バンプ　緑：樹脂　青：Alスプレッダ　橙：PCB</div>

</div>
<div class="model-figs">
  <img class="model-xy" src="model_xy_uniform_N48_v9.png">
  <img class="model-yz" src="model_yz_uniform_N48_v9.png">
  <div class="plot-caption">上：XY断面　下：YZ断面（一様配置 N=48）</div>
</div>
</div>

<!--
目安 0:40。
解析対象は1.2ミリ角、厚さ0.6ミリの3層積層モデルです。
各シリコン層に赤で示す発熱ブロックを4個置き、総発熱量は0.384ワットです。
上面は周囲温度300ケルビンへの対流、側面と下面は断熱としました。
中央1ミリ角がTSVの実装領域で、TSV配置は3層で共通です。
このTSV配置を、次のように少ない数で表します。
-->

---

# TSV密度マップ

個々のTSV座標を入力すると、TSV本数に応じて入力が増加します。そこで、TSV実装領域を4×4に分割し、各セルのTSV本数を温度予測モデルへの入力としました。

<div class="panel-row dens-row">
  <img class="dens-map" src="density_map_random_N48_v6.png">
  <div class="arrow dens-arrow">→<br><span class="small">展開</span></div>
  <img class="dens-xy" src="material_xy_random_N48_v6.png">
</div>

<div class="flow compact-flow">
  <div class="node">TSV座標<br><em>N</em>本 × (<em>x</em>, <em>y</em>) ＝ 2<em>N</em>個</div><div class="arrow">→</div>
  <div class="node">4×4セルごとに<br>本数を集計</div><div class="arrow">→</div>
  <div class="node accent">密度マップ<br>16個（<em>N</em>によらず一定）</div>
</div>

<!--
目安 0:45。
個々のTSV座標をそのまま設計変数にすると、TSV本数とともに入力が増え、学習と探索が難しくなります。
そこでTSV実装領域を4掛ける4に分け、各セルのTSV本数を固定長16成分の密度マップとして表しました。
左が48本のランダム配置の密度マップ、右がそこから展開した実際のTSV配置です。セルの数字と、その中のTSVの本数が対応しています。
この16個を入力として温度場を予測するモデルを、次に説明します。
-->

---

# 縮約モデル（ROM）

複数のFVM温度場から、温度分布の変化を表す**主要な空間パターン**を抽出します。

<div class="flow compact-flow">
  <div class="node">複数の<br>FVM温度場</div><div class="arrow">→</div>
  <div class="node accent">ROMによる<br>パターン抽出</div><div class="arrow">→</div>
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
この係数を、前のスライドの密度マップから求めます。次に、その構築方法を説明します。
-->

---

# ROMの構築方法

ROM構築には、3種類のTSV本数についてFVMで計算した**300配置の温度場**を使用しました。

<div class="split-row">
  <div class="split"><strong>100</strong><br>N=36</div>
  <div class="split"><strong>100</strong><br>N=48</div>
  <div class="split"><strong>100</strong><br>N=60</div>
</div>

<div class="flow compact-flow" style="margin-top:25px;">
  <div class="node">FVM温度場<br>300配置</div><div class="arrow">→</div>
  <div class="node accent">POD基底<br>24モード</div><div class="arrow">→</div>
  <div class="node">密度マップから<br>RBFで係数予測</div><div class="arrow">→</div>
  <div class="node">三次元温度場を<br>再構成</div>
</div>

<div class="method-note">24モードおよびRBF条件は、ROM構築用とは別の<strong>モデル選定42配置</strong>で決定しました。</div>

<!--
目安 0:55。
ROM構築には、TSV本数36、48、60の各100配置、合計300配置のFVM温度場を使用しました。
これらからPOD基底を構築し、密度マップから24個の係数をRBFで予測して温度場を再構成します。
モード数とRBFの条件は、構築用とは別の42配置で選定しました。
ここまでは構築方法であり、次に独立したデータで精度を確認します。
-->

---

# ROMの精度検証結果

<div class="acc-row">
<div>
  <img class="acc-plot" src="rom_accuracy_independent_v7.png">
</div>
<div>

**横軸**：FVMの最高温度<br>**縦軸**：ROMの最高温度

- ROMの構築に使っていない**42配置**で評価
- 破線（y = x）からの距離が、FVMとROMの最高温度の誤差を表す

<div class="acc-result">
<div class="acc-head">結果</div>
<div>最高温度の平均誤差：<strong>0.0950 K</strong></div>
<div>温度場の2乗平均誤差：<strong>0.493 %</strong></div>
<div class="acc-note">（300 Kからの温度上昇に対する比）</div>
</div>

</div>
</div>

<!--
目安 1:00。
ROMの構築に使っていない42配置で、FVMとROMの最高温度を比較しました。
横軸がFVM、縦軸がROMの最高温度で、破線からの距離が両者の誤差を表します。
最高温度の誤差は平均0.0950ケルビンでした。
温度場全体でも、2乗平均の誤差は300ケルビンからの温度上昇の0.493パーセントでした。
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

<small>改善する近傍がなくなるまで反復し、各Nの400初期配置から得た候補のうち、ROM予測Tmaxが最も低い配置を選びました。</small>

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

<div class="trade-fig">
  <img class="trade-plot" src="tmax_vs_count_v10.png">
</div>

<div class="plot-caption">ROMによる予測値（N=36〜60の25水準）</div>

> **同じTSV本数でも、配置探索によって一様配置より低温な候補が得られました。**

<small>本数別局所探索で得た候補を並べた近似トレードオフです。大域最適解または真のパレートフロントを示すものではありません。</small>

<!--
目安 0:50。
横軸がTSV本数、縦軸が最高温度で、どちらもROMによる予測値です。
灰色が一様配置、青色が各本数で探索された低温候補です。
本数を増やすほど最高温度が低下するとともに、同じ本数でも探索候補は一様配置より低温になっています。
この曲線は各本数の局所探索結果を並べたもので、真のパレートフロントではありません。
次に、選んだ候補をFVMで確認した結果を示します。
-->
---

# 探索候補のFVM再検証

<div class="two-col" style="grid-template-columns:1.05fr 0.95fr;gap:24px;align-items:start;">
  <div>
    <div class="map-pair">
      <div>
        <div class="map-title">探索で得た低温候補（N=48）</div>
        <div class="density-grid">
          <div class="cell d3">3</div><div class="cell d9">9</div><div class="cell d0">0</div><div class="cell d1">1</div>
          <div class="cell d9">9</div><div class="cell d9">9</div><div class="cell d8">8</div><div class="cell d0">0</div>
          <div class="cell d4">4</div><div class="cell d0">0</div><div class="cell d1">1</div><div class="cell d0">0</div>
          <div class="cell d0">0</div><div class="cell d1">1</div><div class="cell d0">0</div><div class="cell d3">3</div>
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
    <img src="fvm_reduction_v7.png" style="width:500px;max-height:470px;">
  </div>
</div>

> **FVM再計算でも、一様配置より1.119〜1.376 K低温でした。**

<small>密度マップの数字はセルごとのTSV本数。結果は固定した発熱分布と解析条件に対する低温候補です。</small>

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
  <div class="summary"><strong>0.0950 K</strong><br><span class="small">独立評価の<br>Tmax MAE</span></div>
  <div class="summary"><strong>25水準</strong><br><span class="small">N=36〜60を<br>本数別に探索</span></div>
  <div class="summary"><strong>1.119–1.376 K</strong><br><span class="small">FVM確認済み<br>低減量</span></div>
</div>

**密度マップ → ROM構築・精度確認 → 本数別探索 → FVM再確認**

<small>結論の範囲は、固定した非一様発熱分布、境界条件、TSV径、3層共通配置です。ROMはFVMの完全な代替ではありません。</small>

<!--
目安 0:40。累積約10:05。
まとめです。
300配置のFVM温度場からPOD–RBF ROMを構築しました。
独立評価42配置の最高温度を平均0.0950ケルビンの誤差で予測しました。
このROMを使って36本から60本までの25水準を本数別に探索しました。
選んだ候補はFVMでも一様配置より1.119から1.376ケルビン低温でした。
以上から、固定条件の範囲で、ROMをFVMで再計算すべき低温候補の選別に利用できました。
-->
