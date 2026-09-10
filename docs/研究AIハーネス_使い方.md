# 軽量研究AIハーネスの使い方

更新：2026-09-10。研究方法をAIが先回りして選ぶことを抑える、会話・承認記録・事前照合の最小版。
研究条件そのものは決めない。共通方針の正本は [agent_policy.md](../.kiro/steering/agent_policy.md)。

## 現在の導入状態

- 作業票検査CLIとテストは `tools/research_harness/` に実装。
- 本人による手動配置後、`.agents/skills/` の研究Skill3件と `.codex/agents/` の研究役4件を確認。導入時点では `tools/research_harness/skills/`、`tools/research_harness/agents/` の対応ソースと7件とも一致した。
- このセッションで研究Skill3件が利用可能一覧へ認識された。`research-extractor` を役名で起動し、限定した配置確認が完了した。全役の有効モデル・権限や、計算禁止を検証済みとは扱わない。
- グローバル設定、既存Kiro本文、既存spec、研究コード・データ、`slide` リポジトリは変更していない。

## 始め方

相談と実装は別チャットにする。相談側から渡すのは採用判断・未決・根拠への参照だけ。会話の候補を丸ごと実装指示にしない。

| 用途 | このリポジトリのチャットに渡す依頼例 |
|---|---|
| 研究相談 | `$research-consult ○○を相談したい。採用・実装・実験はまだしない。` |
| 要件・実装 | `$research-workflow 対象specと作業票を確認して進めて。未決は埋めずに戻して。` |
| 資料作成 | `$research-slides 指定した進捗と図だけで構成案を作って。掲載内容を確認するまで描画しない。` |

Skill一覧に出ないクライアントでは、対応する `.agents/skills/research-*/SKILL.md` の実ファイルを指定して読ませる。配置先を読めない別チャットでは、必要な手順と承認済みの引継ぎを明示して渡す。

機械的に研究計算を不可能にする相談入口は、研究マシンの実行ツールを接続しないチャットで、必要な資料だけを渡す方式。Codexのread-onlyモードだけでは計算禁止にならない。資料に機密が含まれる場合の外部送信は別途判断する。

## 作業票

一つの小さい作業につき一つ。対象spec内など、既存の作業文書と同じ場所に置く。[雛形](../tools/research_harness/work-order.example.json) の整形はAIが担当し、本人は自然文で方法・範囲を確認する。単発の読取り相談に起票を強制しない。

- `scope.objective` / `task_refs`：目的と既存の対象task。要件・設計・タスク本文はKiroを正本とし、二重作成しない。
- `decisions`：本人が採用した研究判断のID→明示内容。方法を選ぶ必要がない作業は空でよい。未決を空文字や推測の初期値で埋めず `unresolved` に入れる。
- `references`：依存する要件・設計・判断・根拠の正確なファイル。任意の `heading` は一意なMarkdown見出し行（例 `## R1`）で、その節と下位節だけを束縛する。見出し省略はファイル全体。関連する全資料を選ぶ責任は担当者にあり、CLIは抜けた資料の意味を推測しない。
- `operations`：工程ごとの許可対象。各工程に `write_files`（正確な相対ファイル名）と `commands`（argv配列の一覧）を持つ。一作業票はimplement/test系、またはslides系のどちらかで、混在を拒否する。
- `operations.implement`：編集先を列挙しcommandsは空。実装checkでは実際の--writeが必須。root・ディレクトリ・glob・symlinkを書込先に指定しない。
- `operations.test`：実装とは別に、テストコマンドとその副生成物の書込先を列挙する。実際のargvが必須。実装許可だけではコマンド実行の許可にならない。小さい研究実験をテストと分類しない。
- `operations.slides`：スライド原稿・assets・配布物だけを列挙し、再描画等のコマンドがあれば指定する。描画前は実際の--write、描画後はmanifestを検査する。これらはホストの実権限を拡大しない。
- `presentation`：資料作成以外はnull。作成する場合は後述。
- `state.phase`：`draft` / `ready` / `blocked` / `complete`。自動遷移はしない。
- `approvals`：`implement`、`test`、`slides`を必要なものだけ記録する。許可は対応する工程の対象だけに有効。scope全体をhashで固定するので、無関係な作業は別票に分ける。

```json
{
  "operations": {
    "implement": {"write_files": ["src/example.py"], "commands": []},
    "test": {"write_files": [], "commands": [["python3", "-m", "unittest", "test_local"]]}
  }
}
```

初回の起票後、本人へ目的・方法・変更先・テスト・実験なし等を短く提示する。既に現在の依頼で具体的に許可されているなら、その応答を記録し同じ質問を繰り返さない。範囲が曖昧なら必要な点だけ尋ねる。

```bash
python3 -B tools/research_harness/harness.py digest path/to/work-order.json
python3 -B tools/research_harness/harness.py check path/to/work-order.json --action implement --write src/example.py
python3 -B tools/research_harness/harness.py check path/to/work-order.json --action test --command-json '["python3","-m","unittest","test_local"]'
```

本人の明示応答に基づき、該当actionに次を記録する。digestを計算しただけでは承認は発生しない。

```json
{"scope_hash":"確認した範囲のSHA-256","user_message":"本人の応答を辿れる参照","user_quote":"実際の承認文の短い引用"}
```

`ready` は本人の許可と未決解消を確認してから設定する。承認時のhashを、変更後のhashへ機械的に差し替えてはいけない。検査は承認引用の本人性を検証できないため、実操作の担当者は現在のユーザー指示と照合する。会話が辿れず確認不能なら再確認する。AIレビュー結果だけでは代替できない。

CLIは `RECORD_CHECK_PASS` または `REJECTED`（終了コード2）を返す。外部操作・シェル・承認発行は一切実行しない。指定操作の直前に使用するが、これを必ず経由させる強制ゲートではない。

argv照合は、呼出し先コード・cwd・環境・副作用の安全性を証明しない。実行直前に実体と影響を確認し、研究計算か曖昧なら実行せず本人へ戻す。許可したargvの参照先へ計算を混入してよい、という意味ではない。固定すべきrunner・設定はreferencesに登録できるが、任意の依存コードまで自動追跡する機能はない。

hashは作業ID、root、scope全体、選択した参照の現在内容を束縛する。無関係な節やnotesの変更は承認を失効させない。参照は最大16件、各8MiB以下に限定し、大型runの一括読込・hashはしない。rootは既定でcwd、別の明示対象は `--root`。相対参照はroot基準、絶対参照も読取りには使える。出力はroot内の正確な相対パスのみ。

## 差戻し

影響する作業の `state` に次を残し、その作業を停止する。

```json
{
  "phase": "blocked",
  "reason": "不足または矛盾の具体的内容",
  "evidence_refs": ["実際の根拠"],
  "affected_tasks": ["対象task"],
  "return_to": "consult",
  "decision_needed": "本人または仕様確認で解決すべき点",
  "preserved_artifacts": ["既存成果物の参照"]
}
```

戻り先は、研究方法→`consult`、ソフトウェア契約→`spec`、実装不良→`implement`、掲載範囲・説明→`storyboard`。作業再開時は根拠と最新依頼を確認し、範囲変更があれば再承認する。同じ範囲の実装バグの修正まで毎回研究方針を再承認しない。未解決なのにreadyへ戻さない。科学的状態は既存の正本を使い、新しい全体dashboardは作らない。

## スライド

流れ：指定進捗の読取り → 主張・根拠と構成案 → 本人の掲載承認 → 描画 → 根拠・範囲レビュー → 本人の説明確認。構成案作成と発表用の採用は区別する。

作業票は `scope.operations` をslidesだけにし、`scope.presentation` を次の形にする。根拠と入力は `references` に登録してhashの対象にする。再描画する場合は生成スクリプトも登録する。

```json
{
  "claims": {"C1": {"text": "採用された主張と留保", "evidence": ["docs/report.md"]}},
  "figures": {"F1": {
    "inputs": ["selected-data.csv"], "series": ["A", "B"],
    "transform": "none（集計・正規化なし）",
    "axes": {"x": "ケースID", "y": "温度 [K]"}, "claims": ["C1"]
  }}
}
```

既存の `source-notes.yml` は保持する。新しい日付の記録からwork-orderと `figure-manifest.json` を参照する形で接続し、既存YAMLの一括変換や新しいYAML依存は導入しない。

manifestは `{ "presentation": 実際の描画入力に基づく掲載内容, "artifacts": [{"path":"slides.md","sha256":"実ファイルのSHA-256"}, …] }`。図・原稿・最終PDF/PPTX等、配布する全ファイルと表示に必要なassetsを含める。配布物の漏れは人と独立レビューで確認し、CLIがディレクトリから自動検出するとは扱わない。

```bash
python3 -B tools/research_harness/harness.py check path/to/work-order.json --action slides --write slides.md
python3 -B tools/research_harness/harness.py check path/to/work-order.json --action slides --manifest path/to/figure-manifest.json
python3 -B tools/research_harness/harness.py manifest-digest path/to/figure-manifest.json
```

checkは主張・図・系列・変換・軸等の一致と列挙成果物のhashを検査する。図そのものを理解して検査するわけではない。実入力・生成コード・実画像も照合する。出典不明の図には根拠を捏造せず、草稿の不足事項として残す。

描画・PDF変換等でコマンドを実行する場合は、直前checkに `--command-json '<実際のargv配列>'` も必ず渡す。--writeだけの合格はコマンド実行の照合をしていない。

本人が重要な図の比較対象・方法選択理由・言える範囲を説明できると確認した応答を、`presentation_acceptance` に記録する。項目は通常の承認記録に `manifest_hash` と `explanation_confirmed: true` を加えたもの。AI自身が理解済みにしない。

```bash
python3 -B tools/research_harness/harness.py check path/to/work-order.json --action present --manifest path/to/figure-manifest.json
```

確認前は草稿。説明できない部分は相談または構成案へ戻す。成果物が変われば説明確認もやり直す。既存の矛盾や留保を隠して「説明しやすさ」を達成しない。

## モデル

初期割当であり、効率優位を実測した結論ではない。グローバル既定を変えず、通常の主担当も用途に合わせて選ぶ。

| 工程 | モデル／推論 | 役 |
|---|---|---|
| 指定資料からの事実抽出 | Luna／low | research-extractor |
| 要件整理・一次資料探索・スライド構成 | Terra／medium | 主担当、必要時research-evidence |
| 仕様が明確な実装 | Terra／high | 単一の編集主担当 |
| 理論比較・数値実装の難所 | Sol／high | 相談・編集主担当 |
| 独立レビュー | Sol／high | research-reviewer |
| 一つの難しい横断問題 | Astra／high | research-escalation、本人の個別許可が必要 |

通常は主担当1と必要時の子1。独立した読取り2件だけ同時子2まで。1作業の初期起動目安は2回、追加の必要があれば理由を報告する。子の再委任なし、同じ失敗への修正は最大2回で原因を整理する。必須レビューを回数節約で省略しない。親が把握した短い確認は再委任しない。

役定義を認識しているクライアントでは役名を指定し、対象資料・承認範囲・短い問いを渡す。認識できないクライアントは明示モデル指定等の対応可否を確認し、黙って別モデルへ置換しない。自分のモデルを会話中に切替済みと称さず、主担当変更は新しいセッションやUIのモデル選択を使う。全履歴の継承を既定にしない。

CLIで通常の主担当を選ぶ例（コマンドは本人が新しいセッションを起動するもの）：

```bash
codex -m gpt-5.6-terra -c model_reasoning_effort='"high"' -s workspace-write -a untrusted -C /home/foo/somad_dev3
```

これは広いworkspace-writeであり、作業票のファイル単位の隔離を実現しない。手順の遵守を前提とする補助運用に限定し、強い隔離が必要な相談には使わない。

必要時だけ作業票の隣へ利用量JSON配列を記録する。各行は `task_id, reason, requested_model, effective_model, effort, elapsed_seconds, tokens, retries` 等。取得不能値はnull。集計は `harness.py usage path/to/usage.json`。既知分と未取得件数を分け、欠測を0にしない。API金額と契約の利用枠を混同せず、今回は効率比較の自動実験を行わない。

## コミット

本人の「こまめにコミット」の依頼を反映し、検証済みの小さな変更単位ごとに主担当がローカルcommitする。方針の正本は `agent_policy.md` §7。研究上の承認、実験、pushの許可とは別である。

流れは、作業前の既存変更確認 → 範囲内の編集 → 局所検証・必要なレビュー → 対象path/hunkだけstage → staged差分確認 → commit → IDと残りを報告。追加の常駐処理やGit自動実行ツールは導入しない。ハーネスCLIは引き続き記録検査のみで、Gitコマンドを実行しない。

既存変更が同じファイルに混在したら、安全に分離できる箇所だけ記録し、できなければそのファイルを保留する。草稿は草稿として記録し、Gitにあることを本人承認済みと読み替えない。コミットIDを記録するためだけの再commitを繰り返さない。

## 制約と今後の運用

この最小版は意図の逸脱を減らす補助手順であり、悪意あるエージェントにも破れない認証・sandboxではない。AI可書込の承認記録、任意shell、実画像の意味、未列挙の成果物には人の照合が残る。数値実験の汎用runner、常駐エージェント、DB、自動状態機械は持たない。

運用上の正本は `.agents/skills/research-*/` と `.codex/agents/research-*.toml`。`tools/research_harness/skills/` と `tools/research_harness/agents/` は再配置用の複製として同じ変更単位で同期・比較し、独立して方針を編集しない。更新時は既存同名を無条件上書きせず差分確認する。保護された場所の変更は承認機構を使い、迂回コピー・symlinkで保護を回避しない。

クライアントを変えた場合もSkill発見と役の有効モデル・権限を確認する。役のread-only指定だけを信用せず、親からの権限継承と区別する。入れ子sandboxの過去の起動失敗は未解消であり、強制隔離は未検証。`slide` 側への導入・実出力は当該workspaceを明示した作業で別途行う。

設定仕様の確認元：[公式Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)、[公式Config Reference](https://learn.chatgpt.com/docs/config-file/config-reference)。CLI 0.146.1のhelp/featuresも照合した。公式の仕様記述と、このホストでの実効性は分けて扱う。
