---
marp: true
math: mathjax
theme: default
paginate: true
size: 16:9
title: 補助スライド（熱工学コンファレンス2026 B11）
author: 大屋 蒼真
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
  .model-row { display:grid; grid-template-columns:0.95fr 1.05fr; gap:22px; align-items:start; }
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
  img.trade-plot { width:1100px; }
  .trade-row { display:grid; grid-template-columns:1.15fr 0.85fr; gap:20px; align-items:start; margin-top:6px; }
  .trade-row ul { margin:0; padding-left:1.1em; font-size:22px; }
  .trade-row li { margin:3px 0; }
  .trade-row .acc-result { margin-top:0; font-size:23px; line-height:1.5; padding:8px 16px; }
  .trade-row .acc-note { margin-top:6px; font-size:18px; }
  .bg-step { font-size:30px; line-height:1.45; margin:6px 0; }
  .bg-sub { font-size:20px; color:#59616b; margin:0 0 2px; }
  .axis-grid { display:grid; grid-template-columns:auto auto; column-gap:28px; row-gap:2px; font-size:22px; margin-bottom:6px; justify-content:start; }
  img.cmp-map { height:235px; display:block; }
  .fvm-row { display:grid; grid-template-columns:270px 270px 1fr; gap:16px; align-items:start; }
  .fvm-col { text-align:center; }
  .fvm-col .map-title { font-size:21px; margin-bottom:2px; }
  img.fvm-img { width:270px; display:block; margin:0 auto 4px; }
  .fvm-desc { font-size:19px; line-height:1.4; color:#25272b; margin-bottom:10px; }
  .rom-fvm { margin-top:10px; border-left-color:#741b47; background:#f6edf2; font-size:22px; }
  .compress { text-align:center; font-size:23px; margin-top:10px; padding:8px 14px; background:#f6edf2; border-radius:8px; }
  .rom-pod { font-size:22px; color:#59616b; }
  .rom-coef { margin-top:18px; padding:10px 16px; border-left:6px solid #741b47; background:#f6edf2; font-size:25px; }
  .rom-legend { font-size:23px; line-height:1.6; }
  .rom-legend mjx-container { font-size:23px; }
  .rom-def { font-size:22px; line-height:1.5; margin-top:8px; }
  .rom-def div + div { margin-top:4px; }
  .step-flow { align-items:stretch; margin-top:20px; }
  .step-flow .arrow { align-self:center; }
  .step-flow .node { font-size:22px; }
  .search-flow { margin:22px 0 0; }
  .search-flow .node { width:230px; box-sizing:border-box; min-width:0; }
  .loop-line { position:relative; margin:0 0 0 574px; width:285px; height:28px; border:2px solid #741b47; border-top:none; }
  .loop-line::before { content:"▲"; position:absolute; left:-10px; top:-12px; color:#741b47; font-size:16px; line-height:1; }
  .loop-back { color:#741b47; font-size:22px; margin:4px 0 0 516px; width:400px; text-align:center; }
  .search-note { font-size:21px; color:#59616b; text-align:center; margin-top:18px; }
  .search-multi { margin-top:20px; padding:10px 16px; border-left:6px solid #741b47; background:#f6edf2; font-size:25px; }
  .sum-row { margin-top:10px; }
  .sum-row ul { margin:0; padding-left:1.1em; font-size:23px; }
  .sum-row li { margin:6px 0; }
  .sum-boxes { display:flex; gap:16px; margin-top:14px; }
  .sum-boxes .summary { min-height:0; padding:12px 8px; }
  .sum-boxes .summary strong { font-size:30px; }
  .sum-boxes .summary .small { display:block; min-height:58px; line-height:1.4; }
  .sum-scope { margin-top:18px; font-size:20px; color:#59616b; }
  .down { color:#741b47; font-size:30px; line-height:1; margin:0 0 0 1.2em; }
  .plot-caption { text-align:center; font-size:20px; color:#59616b; margin-top:0; }
  .b1-row { display:grid; grid-template-columns:auto 1fr; gap:22px; align-items:center; }
  .b1-figs { display:flex; align-items:center; gap:10px; }
  .b1-fig { text-align:center; }
  img.b1-map { height:225px; display:block; margin:0 auto; }
  img.b1-rule { height:225px; display:block; margin:0 auto; }
  .b1-cap { font-size:17px; color:#59616b; text-align:center; line-height:1.3; }
  .b1-text ul { margin:0; padding-left:1.1em; font-size:21px; }
  .b1-text li { margin:4px 0; }
  img.b1-ex { display:block; width:760px; margin:6px auto 0; }
  .b1-key { margin-top:10px; padding:8px 16px; border-left:6px solid #a13d22; background:#fff1eb; font-size:23px; text-align:center; }
  .b2-row { display:grid; grid-template-columns:1.1fr 0.9fr; gap:28px; align-items:start; }
  .b-head { font-weight:700; color:#741b47; font-size:23px; margin-bottom:6px; }
  .b-note { font-size:18px; color:#59616b; line-height:1.35; margin-top:6px; }
  section table { font-size:20px; border-collapse:collapse; margin:0 auto; }
  section th, section td { padding:5px 12px; }
  .b3-eq { font-size:22px; }
  .b3-eq p { margin:4px 0; }
  .b3-eq mjx-container[display="true"] { font-size:25px; margin:4px 0 !important; }
  .b-points ul { margin:8px 0 0; padding-left:1.1em; font-size:22px; }
  .b5-legend { padding:6px 14px; border-left:4px solid #741b47; background:#f7f7f8; font-size:19px; line-height:1.6; margin-top:6px; }
  .b5-legend mjx-container { font-size:19px; }
  .b5-legend p { margin:0; }
  img.b-plot { width:610px; display:block; }
  img.b6-plot { width:690px; display:block; margin-left:-20px; }
---

# 密度マップから実座標への変換

<div class="b1-row">
<div class="b1-figs">
  <div class="b1-fig"><img class="b1-map" src="density_map_random_N48_v6.png"><div class="b1-cap">密度マップ（各セルの本数）</div></div>
  <div class="dens-arrow">→</div>
  <div class="b1-fig"><img class="b1-rule" src="backup_cell_rule_v1.png"><div class="b1-cap">1セル内の候補位置と選ぶ順</div></div>
</div>
<div class="b1-text">

- TSV実装領域 1.0 mm角を4×4に分割（1セル250 µm角）
- 最小ピッチ80 µm → 候補位置3×3＝**9点**（1セル最大9本）
- セルの本数 n ＝ round(μ × 9)
- **セル中心に近い順**に n 点を選択<br>①中心 → ②上下左右 → ③四隅

</div>
</div>

<img class="b1-ex" src="backup_cell_examples_v1.png">
<div class="b1-cap">FVMの材料分布（上の密度マップの4セルを拡大、黄：TSV、破線：候補位置）</div>

<div class="b1-key">配置は本数から一意に決まる → 設計変数＝16セルの本数</div>

<!--
補助。密度マップから実際のTSV座標への変換です。
実装領域1ミリ角を4×4に分け、1セルは250マイクロメートル角です。最小ピッチ80マイクロメートルから、1セルに置ける候補位置は3×3の9点で、これが1セル最大9本の根拠です。
各セルの本数を、セル中心に近い候補位置から順に置きます。中心、上下左右、四隅の順です。
下は実際のFVMの材料分布で、本数どおりに置かれていることが確認できます。
したがって、配置は16セルの本数から一意に決まり、本研究の設計変数は16セルの本数そのものです。
（中心からの距離が同じ候補の間の順番は、生成コードの数値丸めで決まる固定の順で、設計変数ではありません。）
-->

---

# 密度マップの解像度

<div class="b2-row">
<div>

<div class="b-head">予測方法の比較（独立評価42配置）</div>

| 予測方法 | 入力 | 最高温度の平均誤差 |
|---|---|---:|
| 定数（学習平均） | なし | 1.46 K |
| 本数のみ（線形） | N | 0.37 K |
| 16セルの本数（線形） | 密度マップ | 0.146 K |
| **ROM（POD–RBF）** | 密度マップ | **0.095 K** |

<div class="b-note">本数だけでは不十分、配置（16セル）の情報で誤差が1/4以下</div>

</div>
<div>

<div class="b-head">予備検討：入力解像度の比較</div>

| 密度マップ | 温度場L2誤差 |
|---|---:|
| 2×2 | 0.434 % |
| **4×4** | **0.077 %** |
| 8×8 | 0.097 % |
| 16×16 | 0.097 % |

<div class="b-note">同じTSV配置を各解像度で表しROMを構築<br>（2026-08の予備検討、60×60×30格子、本研究とは条件が異なる）</div>

</div>
</div>

<div class="b1-key">本研究の配置は4×4の本数で定義 → 入力の段階で情報の欠落なし</div>

<!--
補助。密度マップは4×4で十分か、という質問への回答です。
まず、本研究では配置そのものが4×4セルの本数で定義されているので、ROMの入力として情報は落ちていません。
左は予測方法の比較です。本数だけを使う線形モデルでは0.37ケルビン、16セルの本数を使う線形モデルで0.146ケルビン、ROMで0.095ケルビンでした。配置の情報が効いていることが分かります。
右は8月の予備検討で、同じ配置を2×2から16×16で表してROMを作った結果です。4×4が最も小さく、細かくしても改善しませんでした。ただし格子や条件が本研究と異なる参考値です。
より細かい配置自由度を扱うことは今後の課題です。
-->

---

# PODとSVD

<div class="b3-eq">

学習300配置の温度場（1,728,000セル）から平均場を引いて並べる

$$
X = \left[\, \boldsymbol{T}_1 - \bar{\boldsymbol{T}},\ \dots,\ \boldsymbol{T}_{300} - \bar{\boldsymbol{T}} \,\right] \in \mathbb{R}^{1{,}728{,}000 \times 300}
$$

特異値分解（SVD）

$$
X = U \Sigma V^{\mathsf T}, \qquad \boldsymbol{\phi}_j = U \text{ の第 } j \text{ 列},\quad \sigma_1 \ge \sigma_2 \ge \cdots
$$

上位 r 個の基底で温度場を近似

$$
\boldsymbol{T}(\boldsymbol{\mu}) \approx \bar{\boldsymbol{T}} + \sum_{j=1}^{r} a_j(\boldsymbol{\mu})\, \boldsymbol{\phi}_j,
\qquad a_j^{(k)} = \boldsymbol{\phi}_j^{\mathsf T}\!\left(\boldsymbol{T}_k - \bar{\boldsymbol{T}}\right)
$$

</div>

<div class="b-points">

- 基底 φ_j は互いに直交、r 個の基底で表す近似の中で2乗誤差が最小
- 累積寄与率 ＝ σ₁² + … + σ_r² を全体で割った値

</div>

<!--
補助。PODの中身です。
学習用300配置の温度場から平均場を引いて、172万8000セル×300の行列を作ります。
これを特異値分解すると、左特異ベクトルがPODの基底、特異値がその重要度になります。
上位r個の基底の重ね合わせで温度場を近似し、学習配置の係数は基底への射影で求めます。
基底は互いに直交していて、r個で表す近似の中で2乗誤差が最小になります。
-->

---

# 累積寄与率

<div class="acc-row">
<div>
  <img class="b-plot" src="backup_pod_ric_v1.png">
</div>
<div>

<div class="axis-grid"><div><b>横軸</b>：POD基底の数 r</div><div><b>縦軸</b>：1 − 累積寄与率（対数）</div></div>

- 学習300配置の温度場から計算
- ★：採用した r = 24

<div class="acc-result">
<div class="acc-head">結果</div>
<div>r = 1：0.9624</div>
<div>r = 24：<strong>0.999782</strong></div>
<div class="acc-note">保持した60基底（全分散の99.99 %以上）に対する比</div>
</div>

<div class="b-note">r は寄与率ではなく、検証用42配置の誤差で選定（次のスライド）</div>

</div>
</div>

<!--
補助。累積寄与率です。
縦軸は1から累積寄与率を引いた値を対数で示しています。
1個目の基底だけで0.962、採用した24個で0.999782でした。
この値は、保持した60基底に対する比です。60基底で全分散の99.99パーセント以上を占めます。
なお、基底の数は寄与率のしきい値ではなく、検証用42配置での最高温度の誤差で選んでいます。
-->

---

# RBF補間による係数予測

<div class="b3-eq">

密度マップ μ（16個）を学習範囲で [0, 1] に正規化 → $\hat{\boldsymbol{\mu}}$

$$
a_j(\boldsymbol{\mu}) = \sum_{k=1}^{300} w_{jk}\, \exp\!\left[ -\left( \varepsilon \,\lVert \hat{\boldsymbol{\mu}} - \hat{\boldsymbol{\mu}}_k \rVert \right)^2 \right]
$$

重みは学習300配置の係数から一括で決定

$$
W = A \left( \Phi + \lambda I \right)^{-1}, \qquad
\Phi_{kl} = \exp\!\left[ -\left( \varepsilon \,\lVert \hat{\boldsymbol{\mu}}_k - \hat{\boldsymbol{\mu}}_l \rVert \right)^2 \right]
$$

</div>

<div class="b5-legend">

$A$：学習配置のPOD係数（r × 300）　$W$：重み（r × 300）

$\varepsilon$：基底の幅（小さいほど滑らか）　$\lambda$：正則化（学習点への過適合を抑える）

</div>

<div class="b-points">

- 予測は300個のガウス関数の重ね合わせ → 1回の評価が軽い
- r, ε, λ は検証用42配置で選定（次のスライド）

</div>

<!--
補助。係数予測に使ったRBF補間です。
密度マップの16個の値を学習範囲で0から1に正規化し、学習300配置との距離に応じたガウス関数の重ね合わせで係数を予測します。
重みは、学習配置のPOD係数から、正則化したカーネル行列の逆を掛けて一括で求めます。
イプシロンは基底の幅、ラムダは正則化の強さです。
-->

---

# モード数・ε・λの選定

<div class="acc-row">
<div>
  <img class="b6-plot" src="backup_rbf_selection_v1.png">
</div>
<div>

<div class="axis-grid"><div><b>横軸</b>：POD基底の数 r</div><div><b>縦軸</b>：最高温度の平均誤差</div></div>

- 検証用42配置で評価
- 192通り（r 8 × ε 6 × λ 4）<br>線：ε ごとに λ の最良値
- 選定に使ったのは**検証用42配置のみ**

<div class="acc-result">
<div class="acc-head">採用（★）</div>
<div>r = 24, ε = 0.05, λ = 10⁻⁶</div>
<div>検証用42配置：<strong>0.072 K</strong></div>
<div>独立評価42配置：<strong>0.095 K</strong></div>
<div class="acc-note">独立評価は選定後に1回だけ実施</div>
</div>

</div>
</div>

<!--
補助。基底の数、イプシロン、ラムダの選び方です。
192通りの組合せを、学習にも評価にも使っていない検証用の42配置で比べ、最高温度の平均誤差が最小の組合せを採用しました。
採用はr=24、イプシロン0.05、ラムダ10のマイナス6乗で、検証誤差は0.072ケルビンです。
精度評価用の42配置は選定に使っておらず、選定後に1回だけ評価して0.095ケルビンでした。
（ε = 0.05 は候補の最小値です。さらに小さいεは試していません。）
-->

---

# 計算時間

| 処理 | 時間 | 条件 |
|---|---:|---|
| FVM 1配置（240 × 240 × 30） | 平均 **400 s**（255〜528 s） | 16配置を並列実行 |
| 学習・評価データ 424配置 | 約 3.0 h | 同上 |
| ROM構築（POD＋192通りの選定） | 3.3 min | — |
| ROM 1回の最高温度評価 | 約 **0.9 ms** | 1スレッド |
| 配置探索（9.4 × 10⁷ 回の評価） | 89 min | 20スレッド |

<div class="b1-key">1回の評価でFVMの約 4 × 10⁵ 倍高速</div>

<div class="b-note">探索中の最高温度は、学習配置で高温になる上位5万セル（全体の2.9 %）に限定して評価。<br>全セルで求めた最高温度との差は最大 2 × 10⁻¹³ K（84配置）。</div>

<!--
補助。計算時間です。
FVMは1配置あたり平均400秒で、424配置のデータ作成に約3時間かかりました。
ROMの構築は選定を含めて3.3分です。
ROMで最高温度を1回評価するのは1スレッドで約0.9ミリ秒で、FVMの約40万倍速いです。
探索ではこれを9400万回行い、20スレッドで89分でした。
なお探索中の最高温度は高温になる上位5万セルだけで評価していますが、全セルで求めた値と一致することを確認しています。
-->

---

# 解析条件の妥当性

<div class="b2-row">
<div>

<div class="b-head">格子収束（N = 48 の4配置）</div>

| | 240 × 240 × 30 | 480 × 480 × 30 |
|---|---:|---:|
| 最高温度の差 | — | 0.014〜0.016 K |
| 最良と最悪の幅 | 2.7914 K | 2.7931 K |
| 4配置の順位 | — | 一致 |

<div class="b-note">ずれはほぼ一定 → 配置間の比較には影響しない</div>

</div>
<div>

<div class="b-head">学習していない本数での精度</div>

| TSV本数 | 配置数 | 最高温度の平均誤差 |
|---|---:|---:|
| 36, 48, 60（学習本数） | 84 | 0.083 K |
| **42** | 20 | **0.090 K** |
| **54** | 20 | **0.073 K** |

<div class="b-note">学習した本数の間でも同程度の精度</div>

</div>
</div>

<!--
補助。解析条件の妥当性です。
左は格子収束です。N=48で最高温度の範囲を等分する4配置を、480×480の格子で再計算しました。最高温度の差は0.014から0.016ケルビンでほぼ一定で、4配置の順位も一致しました。配置間の比較には影響しません。
右は学習していない本数での精度です。N=42と54でも、平均誤差は0.090と0.073ケルビンで、学習した本数と同程度でした。
-->

---

# 温度場全体の最大誤差

<div class="acc-row">
<div>
  <img class="b-plot" src="field_max_error_test.png">
</div>
<div>

<div class="axis-grid"><div><b>横軸</b>：TSV本数 N</div><div><b>縦軸</b>：ROMとFVMの温度差</div></div>

- 独立評価42配置、各配置の全セルで評価
- ◆：最大値　●：99 %点

<div class="acc-result">
<div class="acc-head">結果</div>
<div>最大値：0.28〜0.68 K（温度上昇の1.5〜4.5 %）</div>
<div>99 %点：0.09〜0.23 K</div>
</div>

<div class="b-note">最大誤差の位置：42配置中39配置で発熱ブロックの縁付近（z ≈ 0.2 mm）</div>

</div>
</div>

<!--
補助。温度場全体の最大誤差です。
独立評価の42配置それぞれで、全セルのROMとFVMの差の最大値と99パーセント点を示しています。
最大値は0.28から0.68ケルビンで、温度上昇の1.5から4.5パーセントでした。99パーセント点は0.09から0.23ケルビンです。
最大誤差は発熱ブロックの縁付近に局所的に現れます。
-->
