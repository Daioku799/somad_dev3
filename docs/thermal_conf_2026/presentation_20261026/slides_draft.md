---
marp: true
theme: default
paginate: true
size: 16:9
title: TSV密度マップを用いた縮約モデルによる3D-ICの熱設計最適化の研究
author: 大屋 蒼真
footer: 熱工学コンファレンス2026 / B11 / 草稿
style: |
  section {
    font-family: "Noto Sans CJK JP", "Yu Gothic", sans-serif;
    font-size: 28px;
    color: #17233a;
    padding: 42px 58px;
  }
  h1 { color: #123a63; font-size: 42px; }
  h2 { color: #1d5f8a; }
  strong { color: #b23a2b; }
  .lead h1 { font-size: 48px; }
  .message {
    border-left: 8px solid #1976a3;
    background: #eef7fb;
    padding: 18px 24px;
    margin-top: 20px;
  }
  .metric {
    display: inline-block;
    min-width: 220px;
    margin: 8px;
    padding: 14px;
    text-align: center;
    border: 2px solid #79a9c3;
    border-radius: 10px;
    background: #f7fbfd;
  }
  .small { font-size: 20px; }
  .tiny { font-size: 16px; }
  table { font-size: 23px; }
  img { max-height: 520px; }
---

<!-- _class: lead -->

# TSV密度マップを用いた縮約モデルによる<br>3D-ICの熱設計最適化の研究

### 大屋 蒼真・小野 謙二（九州大学）

<div class="message">
POD–RBF ROMで<strong>FVM再計算すべき低温配置候補</strong>を選別する
</div>

<!--
目安 0:20。
本研究では、TSV配置を密度マップで表し、POD–RBF縮約モデルで温度場を予測しました。
結論は、固定した条件の範囲で、ROMをFVM候補の選別に利用できたというものです。
-->

---

# FVMだけでは多数のTSV配置候補を広く評価しにくい

3D-ICでは、thermal TSVの**本数と配置**が温度場に影響する

```text
多数のTSV配置候補
        ↓
各候補を3次元FVMで評価
        ↓
探索範囲を広げるほど計算回数が増加
```

<div class="message">
研究の問い：ROMで候補を評価し、<strong>最後にFVMで確認する候補</strong>を絞り込めるか
</div>

<span class="small">ROMでFVMを完全に置き換えるのではなく、候補選別に利用する。</span>

<!--
目安 0:55。
配置の組合せは非常に多く、すべてをFVMで評価するのは困難です。
そこでFVMを廃止するのではなく、ROMで候補を絞り、最後にFVMで再確認する流れを考えました。
-->

---

# TSV配置を4×4密度マップとして表現する

![w:1120](../figures/fig1_model_parameterization.png)

<span class="small">3層積層モデル／総発熱量 0.384 W／上面対流・側面下面断熱／FVM 240×240×30セル</span>

<!--
目安 1:15。
TSV実装領域を4×4の16セルに分け、各セルのTSV本数を0から9本としました。
左が入力となる密度マップ、中央が材料分布、右が3層構造の断面です。
この16成分をROMの設計入力として用います。
-->

---

# 424配置を構築・選定・独立評価へ分離した

| 用途 | 件数 | 役割 |
|---|---:|---|
| ROM構築 | **300** | POD基底とRBF写像の構築 |
| モデル選定 | **42** | ROM設定の選択 |
| 独立評価 | **42** | 構築・選定に未使用の配置 |
| 本数補間評価 | **40** | 未学習TSV本数を評価 |

```text
FVM温度場 → PODで低次元化 → RBFで配置から係数を予測 → 温度場を再構成
```

<div class="message">
精度は、ROM構築とモデル選定に使わない<strong>独立評価42配置</strong>で確認する
</div>

<!--
目安 1:10。
424配置を役割ごとに分離しました。
300配置でROMを構築し、42配置で設定を選び、さらに別の42配置で最終的な未知配置性能を評価しました。
40配置は学習していないTSV本数の補間確認に使いました。
-->

---

# ROMは未知配置のホットスポット構造を再現した

![w:1120](../figures/fig3_field_comparison.png)

<span class="small">表示例：独立評価中でTmax誤差が最大の `n60_123`。FVM 315.348 K、ROM 315.639 K。</span>

<!--
目安 1:10。
左がFVM、中央がROM、右がROMからFVMを引いた誤差です。
ここでは見栄えのよい平均的なケースではなく、独立評価中で最高温度誤差が最大だったケースを示しています。
誤差は残りますが、ホットスポットの位置と温度場の構造は再現されています。
-->

---

# 独立評価の最高温度MAEは0.0950 Kだった

![w:900](../figures/fig2_accuracy_verification.png)

<div class="message">
test 42配置：<strong>Tmax MAE 0.0950 K</strong>／温度場相対L2誤差 <strong>0.493%</strong>
</div>

<span class="tiny">相対L2誤差は300 Kからの温度上昇を基準に算出。図右は次スライドで説明する。</span>

<!--
目安 1:20。
左図がFVMとROMの最高温度の比較です。点は対角線の近くに並びました。
独立評価42配置で最高温度の平均絶対誤差は0.0950 Kでした。
また、300 Kからの温度上昇を基準とした温度場全体の相対L2誤差は0.493%でした。
-->

---

# ROMで選んだ候補はFVMでも一様配置より低温だった

| TSV本数 | 探索配置 FVM [K] | 一様配置 FVM [K] | 低減量 [K] |
|---:|---:|---:|---:|
| 36 | 317.599 | 318.954 | **1.355** |
| 48 | 315.618 | 316.994 | **1.376** |
| 60 | 314.167 | 315.286 | **1.119** |

<div class="message">
ROM上だけでなく、<strong>FVM再計算でも1.119〜1.376 Kの低減</strong>を確認した
</div>

<span class="small">代表8配置をFVMで再計算。探索配置は同一本数の一様配置と比較。</span>

<!--
目安 1:35。
ROMで選んだ候補を含む代表8配置をFVMで再計算しました。
ここでは36、48、60本について、探索配置と同じ本数の一様配置を比較しています。
FVMでも、探索配置は一様配置より1.119から1.376 K低温でした。
したがってROMは、FVMで確認すべき低温候補の選別に利用できたと考えています。
-->

---

# 結論は固定条件での候補選別までである

## 今回示した範囲

- 固定した非一様発熱分布・境界条件・TSV径
- 未知**配置**に対するROM精度
- ROMで選んだ候補のFVM再計算

## 示していない範囲

- 探索配置の大域最適性
- 未知の発熱分布・境界条件・TSV径への一般化
- ROMだけによる最終設計の確定

<div class="message">
提出時の旧 `gmax` は、格子依存性と工学的意味を<strong>提出後に再検討中</strong>
</div>

<!--
目安 1:00。
今回の結論には適用範囲があります。発熱分布、境界条件、TSV径を固定した問題です。
また探索で得た配置は低温候補であり、大域最適性を示すものではありません。
提出時には最大三次元温度勾配も比較しましたが、最大値型指標の格子依存性が分かったため、現在は目的関数の意味から再検討しています。
-->

---

<!-- _class: lead -->

# POD–RBF ROMをFVM候補の選別に利用できた

<div>
  <span class="metric"><strong>424</strong><br><span class="small">FVM配置</span></span>
  <span class="metric"><strong>0.0950 K</strong><br><span class="small">未知配置Tmax MAE</span></span>
  <span class="metric"><strong>1.119–1.376 K</strong><br><span class="small">FVM確認済み低減量</span></span>
</div>

<div class="message">
TSV密度マップ → ROM評価 → 候補選別 → FVM再確認
</div>

<!--
目安 0:45。
まとめです。424配置のFVMデータからROMを構築し、未知配置の最高温度を平均0.0950 Kの誤差で予測しました。
ROMで選んだ配置は、FVMでも一様配置より1.119から1.376 K低温でした。
以上から、固定条件の範囲で、POD–RBF ROMをFVM候補の選別に利用できました。
-->
