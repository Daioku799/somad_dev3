---
marp: true
theme: gaia
_class: lead
paginate: true
backgroundColor: #f8fafc
color: #1e293b
style: |
  section {
    font-family: 'Helvetica Neue', Arial, 'Hiragino Kaku Gothic ProN', 'Hiragino Sans', Meiryo, sans-serif;
    padding: 35px 50px;
  }
  h1 {
    font-size: 1.8em;
    color: #0f172a;
    margin-bottom: 10px;
  }
  h2 {
    font-size: 1.4em;
    color: #0f172a;
    border-bottom: 3px solid #3b82f6;
    padding-bottom: 5px;
    margin-top: 0;
  }
  h3 {
    font-size: 1.05em;
    color: #475569;
    margin-top: 5px;
    margin-bottom: 10px;
  }
  h4 {
    font-size: 0.85em;
    color: #64748b;
    margin: 3px 0;
  }
  .grid-2 {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 25px;
  }
  .text-center {
    text-align: center;
  }
  .text-sm {
    font-size: 0.78em;
    line-height: 1.4;
  }
  .text-sm ul {
    margin-top: 3px;
    padding-left: 20px;
  }
  .text-sm li {
    margin-bottom: 2px;
  }
  .bold-blue {
    color: #2563eb;
    font-weight: bold;
  }
  footer {
    font-size: 0.5em;
    color: #64748b;
  }
---

<!-- _class: lead -->
# ROM性能評価・改善 進捗報告
## 実験結果の可視化とロードマップ

**対象レポート**: [rom_progress_report_0707.md](file:///home/somadwsl/somad_dev3/docs/rom_progress_report_0707.md)
**日付**: 2026年7月10日

---

## 実験条件とモデルパラメータ

<div class="grid-2">
<div>

### 低次元化モデル (POD-RBF) の理論
高次元温度場ベクトル $\theta \in \mathbb{R}^{N}$ を、平均温度場 $\bar{\theta}$ と $M$ 個の支配的基底（PODモード） $\phi_i$ の線形結合で近似：

$$\theta(\mu) \approx \bar{\theta} + \sum_{i=1}^{M} a_i(\mu) \phi_i$$

*   **RBF補間**: ガウスカーネルを適用し、設計パラメータ $\mu$ から再構成係数 $a$ への非線形写像を学習。
</div>
<div>

### 実験設定

| 項目 | 設定値 / 条件 |
| :--- | :--- |
| **設計パラメータ $\mu$** | 16次元ベクトル ($4 \times 4$ 密度マップ) |
| **FVM 格子数** | $60 \times 60 \times 30 = 108,000$ 格子 |
| **TSV 物理半径** | $20\,\mu\text{m}$ ($r_{\text{tsv}} = 2.0 \times 10^{-5}\,\text{m}$) |
| **最小 TSV ピッチ** | $80\,\mu\text{m}$ (製造制約) |
| **FVM 境界条件** | 底面: 等温 (300 K) / 他面: 対流熱伝達 |

</div>
</div>

---

## 実験結果1: TSV配置修正前 (境界制限なし)
### 入力密度マップと物理配置の例

境界制限がないため、TSV（黄）がチップの物理境界（グレー）の極限まで配置されています。

<div class="grid-2 text-center">
<div>
  <h4>一様分布 (Snapshot 1)</h4>
  <img src="./images/density_map_1.png" width="180px" style="margin-bottom: 5px; border: 1px solid #e2e8f0;" /><br>
  <img src="./images/snapshot_1_sidebyside_xy_legacy.png" width="340px" />
</div>
<div>
  <h4>四隅集中分布 (Snapshot 3)</h4>
  <img src="./images/density_map_3.png" width="180px" style="margin-bottom: 5px; border: 1px solid #e2e8f0;" /><br>
  <img src="./images/snapshot_3_sidebyside_xy_legacy.png" width="340px" />
</div>
</div>

---

## 実験結果1: 未知パターンに対する予測誤差
### 未知のグラデーション密度パターンに対する予測性能評価 (修正前)

<div class="grid-2">
<div>

*   **入力テスト密度マップ**:
    <div class="text-center" style="margin-top: 10px; margin-bottom: 10px;">
      <img src="./images/density_map_test.png" width="180px" style="border: 1px solid #e2e8f0;" />
    </div>
*   **誤差評価**:
    *   学習データに含まれない「左上から右下へのグラデーション」を入力。
    *   最高温度絶対誤差 (Tmax Error): <span class="bold-blue">1.215 K</span>
</div>
<div>

*   **FVM vs ROM 比較プロット (修正前)**:
    <div class="text-center">
      <img src="./images/rom_fvm_comparison_xy_legacy.png" width="410px" />
    </div>
</div>
</div>

---

## 実験結果2: TSV配置修正後 (境界マージン 0.1 mm)
### 物理配置の適正化 (シリコン境界マージン 0.1 mm 適用)

外周境界から $0.1\,\text{mm}$ の範囲にはTSV（黄）を一切配置しない制約を追加。

<div class="grid-2 text-center">
<div>
  <h4>一様分布 (修正後 Snapshot 1)</h4>
  <img src="./images/density_map_1.png" width="180px" style="margin-bottom: 5px; border: 1px solid #e2e8f0;" /><br>
  <img src="./images/snapshot_1_sidebyside_xy.png" width="340px" />
</div>
<div>
  <h4>四隅集中分布 (修正後 Snapshot 3)</h4>
  <img src="./images/density_map_3.png" width="180px" style="margin-bottom: 5px; border: 1px solid #e2e8f0;" /><br>
  <img src="./images/snapshot_3_sidebyside_xy.png" width="340px" />
</div>
</div>

---

## 実験結果2: 未知パターンに対する予測誤差の改善
### 境界適正化による予測精度の向上

<div class="grid-2">
<div>

*   **改善のポイント**:
    *   シリコン境界マージン導入により、熱拡散挙動が物理的に整合。
    *   最高温度絶対誤差 (Tmax Error):
        1.215 K &rarr; <span class="bold-blue">1.180 K</span> (誤差が縮小)
    *   温度分布等高線の一致度も向上。
</div>
<div>

*   **FVM vs ROM 比較プロット (修正後)**:
    <div class="text-center">
      <img src="./images/rom_fvm_comparison_xy.png" width="410px" />
    </div>
</div>
</div>

---

## 実験結果3: 大規模検証 (交差検証)
### 大規模スナップショットを用いた汎化性能評価

スナップショット数を **33枚** に拡張（学習80%: 26ケース、検証20%: 7ケース）

<div class="grid-2">
<div>

### 評価結果サマリー
*   **平均 L2 相対誤差**: `0.026%` (0.000262)
*   **平均 Tmax 絶対誤差**: <span class="bold-blue">0.0988 K</span>
*   **平均ホットスポット位置誤差**: `24.26 μm` (約1格子セル)
*   **合格率**: <span class="bold-blue">97.0%</span> (33中32サンプルで合格)
    *   合格基準: Tmax誤差 2.0 K以下
</div>
<div>

### 評価のまとめ
*   未知のパラメータを入力した際でも、最高温度の予測精度は合格基準を十分にクリア。
*   実用的な予測モデルとして良好に機能することを確認。
*   **課題**: 唯一不合格となった特異パターン (外挿領域) に対するRBFパラメータの最適化。
</div>
</div>

---

## 実験結果3: 代表的な合格ケース (PASS) の結果
### Sample: 0b41877a-e198-4894-b77f-433b60c3df5e

L2相対誤差: `0.129%` / Tmax絶対誤差: <span class="bold-blue">0.303 K</span>

<div class="grid-2">
<div>

#### 入力した密度マップ $\mu$ ($4 \times 4$)

| | Col 1 | Col 2 | Col 3 | Col 4 |
| :--- | :---: | :---: | :---: | :---: |
| **Row 1** | 0.501 | 0.005 | 0.132 | 0.106 |
| **Row 2** | 0.423 | 0.477 | 0.824 | 0.024 |
| **Row 3** | 0.393 | 0.054 | 0.269 | 0.014 |
| **Row 4** | 0.482 | 0.209 | 0.021 | 0.820 |

</div>
<div class="text-center">

#### FVM vs ROM 比較
<img src="./images/pass_case_comparison.png" width="370px" />

</div>
</div>

---

## 今後の評価・改善ロードマップ (Phase 1 & 2)
### 当面の目標：TSV太さ（半径）のパラメータ化とモデル詳細分析

<div class="grid-2 text-sm">
<div>

### ■ フェーズ1: 現行ROMの詳細調査 (直近)
*   **プロットの改善**:
    *   誤差プロットの符号付き差分化 (FVM - ROM)
    *   相対温度場（正規化）による形状・パターンの比較
*   **評価指標の調査**:
    *   SSIMやL2ノルム差、ホットスポット位置ズレを用いた定量比較
    *   各フェーズ (FVM計算, ROM構築, 予測等) の実行時間計測
*   **自己再現精度の検証**:
    *   学習データ入力時の再現誤差限界の実測
</div>
<div>

### ■ フェーズ2: TSV太さのパラメータ化 (目標)
*   **パラメータベクトルの再定義**:
    *   16次元密度 &rarr; **17次元 (16次元密度 ＋ 1次元TSV半径 $r_{\text{tsv}}$)**
*   **Layout.jl の修正**:
    *   [Layout.jl](file:///home/somadwsl/somad_dev3/H2-main-ext/src/ComponentGenerator/Layout.jl) で固定されている `r_tsv` を動的化
    *   ピッチ制約と半径の関係式の妥当性チェック
*   **modelA.jl での占有面積判定検証**:
    *   [modelA.jl](file:///home/somadwsl/somad_dev3/H2-main-ext/src/modelA.jl) での銅アサイン判定が正常動作するか検証
</div>
</div>

---

## 今後の評価・改善ロードマップ (Phase 3 & 4)
### スナップショット生成からROM構築の拡張、および次元の呪いへの対策

<div class="grid-2 text-sm">
<div>

### ■ フェーズ3: パイプラインの拡張
*   **LHSサンプリングの拡張**:
    *   TSV半径の探索範囲（$10\,\mu\text{m} \sim 40\,\mu\text{m}$）を追加した17次元サンプリング
*   **データセットの再構築**:
    *   配置と太さを組み合わせた新データセットの構築
*   **17次元RBF-ROMの学習・評価**:
    *   [ROMInterpolator.jl](file:///home/somadwsl/somad_dev3/H2-rom/src/ROMInterpolator/ROMInterpolator.jl) を用いた未知のTSV配置＋未知の太さに対するROM予測精度の評価
</div>
<div>

### ■ フェーズ4: 高次元化と「次元の呪い」対策
*   **計算格子の細分化**:
    *   高解像度メッシュ化とROM精度への影響評価
*   **次元の呪いの評価**:
    *   パラメータ次元増加時の予測精度変化の限界探索
*   **不等間隔密度マップ of 検討**:
    *   熱源近傍などを細分化する次元削減手法
*   **将来目標**: 熱源の配置・発熱密度のパラメータ化
</div>
</div>
