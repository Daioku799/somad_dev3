---
marp: true
theme: default
paginate: true
size: 16:9
title: TSV密度マップを用いた縮約モデルによる3DIC の熱設計最適化の研究
author: 大屋 蒼真
footer: 熱工学コンファレンス2026 / B11 / 第2稿
style: |
  section {
    font-family: "Noto Sans CJK JP", "Yu Gothic", "Hiragino Sans", sans-serif;
    font-size: 28px;
    color: #1f2933;
    background: #f7f9fc;
    padding: 46px 68px 40px;
  }
  h1 {
    margin: 0 0 18px;
    color: #12355b;
    font-size: 50px;
    line-height: 1.15;
  }
  h2 { color: #276678; }
  strong { color: #b4432a; }
  table { font-size: 24px; }
  th { background: #e7eef5; }
  img { max-height: 490px; }
  .lead {
    background: linear-gradient(135deg, #eef4f8 0%, #f7f9fc 65%);
  }
  .lead h1 {
    font-size: 48px;
    line-height: 1.25;
  }
  .claim {
    margin: 0 0 18px;
    padding: 12px 18px;
    border-left: 7px solid #276678;
    background: #eaf2f6;
    font-size: 30px;
    line-height: 1.35;
  }
  .takeaway {
    margin-top: 16px;
    padding: 13px 18px;
    border-left: 7px solid #b4432a;
    background: #fff2ed;
    font-size: 28px;
  }
  .conditions {
    margin-top: 10px;
    color: #52616b;
    font-size: 18px;
    line-height: 1.35;
  }
  .flow {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 12px;
    margin: 38px 0 28px;
  }
  .node {
    min-width: 190px;
    padding: 24px 18px;
    border: 2px solid #276678;
    border-radius: 12px;
    background: white;
    text-align: center;
    font-size: 27px;
  }
  .arrow { color: #52616b; font-size: 38px; }
  .metric-row {
    display: flex;
    justify-content: center;
    gap: 24px;
    margin-top: 38px;
  }
  .metric {
    min-width: 250px;
    padding: 22px 14px;
    border: 2px solid #276678;
    border-radius: 12px;
    background: white;
    text-align: center;
  }
  .metric strong { font-size: 46px; }
  .small { font-size: 22px; }
  .two-col {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 34px;
  }
  .panel {
    padding: 18px 22px;
    border-radius: 10px;
    background: white;
    border: 1px solid #d8dee9;
  }
---

<!-- _class: lead -->
<!-- _footer: "" -->

# TSV密度マップを用いた縮約モデルによる<br>3DIC の熱設計最適化の研究

### 大屋 蒼真・小野 謙二（九州大学）

熱工学コンファレンス2026　B11

<!--
目安 0:25。
本研究では、TSV配置を密度マップで表し、POD–RBF縮約モデルを用いて低温となる配置候補を選別しました。
本日は、ROMの予測精度と、選んだ候補をFVMで再確認した結果を報告します。
-->

---

# 多数配置評価の難しさ

<div class="claim">FVMだけでは、多数のTSV配置候補を広く評価することが難しい</div>

<div class="flow">
  <div class="node">多数の<br>配置候補</div>
  <div class="arrow">→</div>
  <div class="node">ROMで<br>一次評価</div>
  <div class="arrow">→</div>
  <div class="node">候補を<br>選別</div>
  <div class="arrow">→</div>
  <div class="node">FVMで<br>再確認</div>
</div>

<div class="takeaway">研究の問い：ROMで、FVM再計算すべき低温配置候補を絞り込めるか</div>

<div class="conditions">ROMはFVMを完全に置き換えるものではなく、候補選別に用いる。</div>

<!--
目安 0:55。
thermal TSVの本数と配置は温度場に影響しますが、配置候補は多数あります。
各候補を三次元FVMで評価すると、探索範囲を広げるほど計算回数が増えます。
そこでROMで一次評価し、FVMで再確認する候補を絞る流れを考えました。
次に、配置をROMへ入力する表現を示します。
-->

---

# 密度マップの導入

<div class="claim">TSV配置を4×4の密度マップとして表現する</div>

![w:1100](../figures/fig1_model_parameterization.png)

<div class="conditions">3層積層モデル／各セル0〜9本／総発熱量0.384 W／上面対流・側面下面断熱／FVM 240×240×30セル</div>

<!--
目安 1:10。
TSV実装領域を4×4の16セルに分け、各セルのTSV本数を0から9本としました。
左が入力となる密度マップ、中央がXY材料分布、右が三層構造のYZ断面です。
この16成分をROMの設計入力として用います。
配置を入力として表せたので、次にROMの構築と評価方法を示します。
-->

---

# ROMの構築・評価方法

<div class="claim">424配置を、ROM構築・モデル選定・独立評価・補間評価に分ける</div>

| 用途 | 配置数 | 役割 |
|---|---:|---|
| ROM構築 | **300** | POD基底とRBF写像の構築 |
| モデル選定 | **42** | ROM設定の選択 |
| 独立評価 | **42** | 構築・選定に未使用の未知配置 |
| 本数補間評価 | **40** | 未学習TSV本数の評価 |

<div class="takeaway">密度マップ → RBFでPOD係数を予測 → 温度場を再構成</div>

<div class="conditions">最終精度は、ROM構築とモデル選定に使用しないtest 42配置で評価する。</div>

<!--
目安 1:15。
全424配置を役割ごとに分離しました。
300配置でROMを構築し、42配置で設定を選び、さらに別の42配置を最終的な独立評価に用いました。
残る40配置では、学習していないTSV本数への補間を確認しました。
ここからは、独立評価における温度場と最高温度の順に結果を示します。
-->

---

# 温度場の再現性

<div class="claim">test中のTmax誤差最大例でも、ホットスポットの位置と温度場の構造を再現した</div>

![w:1100](../figures/fig3_field_comparison.png)

<div class="conditions">表示例：`n60_123`。FVM 315.348 K、ROM 315.639 K。平均的な成功例ではなく、test中のTmax誤差最大例。</div>

<!--
目安 1:10。
左がFVM、中央がROM、右がROMからFVMを引いた符号付き誤差です。
表示したのは見栄えのよい平均例ではなく、test中で最高温度誤差が最大だったケースです。
誤差は残りますが、ホットスポットの位置と温度場の構造は再現されています。
続いて、test全42配置で最高温度誤差を定量化します。
-->

---

# 最高温度の予測精度

<div class="claim">独立評価42配置における最高温度MAEは0.0950 Kであった</div>

![w:860](../figures/fig2_accuracy_verification.png)

<div class="takeaway"><strong>Tmax MAE 0.0950 K</strong>　／　温度場相対L2誤差 <strong>0.493%</strong></div>

<div class="conditions">相対L2誤差は300 Kからの温度上昇を基準に算出。図左がFVM対ROM、図右は次ページのFVM検証に対応する。</div>

<!--
目安 1:15。
左図はFVMとROMの最高温度の比較で、test配置は対角線の近くに並びました。
独立評価42配置で、最高温度の平均絶対誤差は0.0950 Kでした。
温度場全体では、300 Kからの温度上昇を基準とする相対L2誤差が0.493%でした。
この精度を確認したうえで、ROMが選んだ候補をFVMで再計算します。
-->

---

# 配置探索結果のFVM検証

<div class="claim">ROMで選んだ候補は、FVM再計算でも同一本数の一様配置より低温となった</div>

| TSV本数 | 探索配置 FVM [K] | 一様配置 FVM [K] | 低減量 [K] |
|---:|---:|---:|---:|
| 36 | 317.599 | 318.954 | **1.355** |
| 48 | 315.618 | 316.994 | **1.376** |
| 60 | 314.167 | 315.286 | **1.119** |

<div class="takeaway">FVMで確認した最高温度低減量：<strong>1.119〜1.376 K</strong></div>

<div class="conditions">ROMで選んだ候補を含む代表8配置をFVMで再計算。表はN=36、48、60の探索配置と一様配置の比較。</div>

<!--
目安 1:35。
ROMで選んだ候補を含む代表8配置をFVMで再計算しました。
ここでは36、48、60本について、探索配置と同じ本数の一様配置を比較しています。
FVMでも探索配置は一様配置より1.119から1.376 K低温でした。
したがってROM上だけでなく、FVMで確認すべき低温候補を選別できたと考えています。
ただし、この結果から言える範囲には限界があります。
-->

---

# 適用範囲と限界

<div class="claim">本研究で示したのは、固定解析条件における低温候補の選別までである</div>

<div class="two-col">
  <div class="panel">
    <h2>今回示した範囲</h2>
    <ul>
      <li>固定した発熱分布・境界条件・TSV径</li>
      <li>未知配置に対するROM精度</li>
      <li>候補のFVM再計算</li>
    </ul>
  </div>
  <div class="panel">
    <h2>示していない範囲</h2>
    <ul>
      <li>探索配置の大域最適性</li>
      <li>条件外への一般化</li>
      <li>ROMだけによる最終設計の確定</li>
    </ul>
  </div>
</div>

<div class="conditions">提出時の旧gmaxは、格子依存性と工学的意味を提出後に再検討中。</div>

<!--
目安 1:00。
今回の結論は、発熱分布、境界条件、TSV径を固定した問題に限られます。
得られた配置は低温候補であり、大域最適性を示すものではありません。
また、提出時には最大三次元温度勾配も比較しましたが、格子依存性と目的関数としての意味を現在再検討しています。
この範囲を踏まえて結論をまとめます。
-->

---

<!-- _class: lead -->

# まとめ

<div class="claim">POD–RBF ROMを、FVMで再計算すべき低温配置候補の選別に利用できた</div>

<div class="metric-row">
  <div class="metric"><strong>424</strong><br><span class="small">FVM配置</span></div>
  <div class="metric"><strong>0.0950 K</strong><br><span class="small">test Tmax MAE</span></div>
  <div class="metric"><strong>1.119–1.376 K</strong><br><span class="small">FVM確認済み低減量</span></div>
</div>

<div class="takeaway">TSV密度マップ → ROM評価 → 候補選別 → FVM再確認</div>

<div class="conditions">結論の範囲：固定した非一様発熱分布・境界条件・TSV径。</div>

<!--
目安 0:45。
まとめです。
424配置のFVMデータからROMを構築し、未知配置の最高温度を平均0.0950 Kの誤差で予測しました。
ROMで選んだ配置は、FVMでも一様配置より1.119から1.376 K低温でした。
以上から固定条件の範囲で、POD–RBF ROMをFVM候補の選別に利用できました。
-->
