# Phase 1 自動抽出 E2E テスト記録 (2026-05-29)

## 0. テストの目的

Phase 1 で実装した `--auto-extract` フローが、実 RDS SQL Server に対して
End-to-End で動作することを検証する。

検証項目:
1. `deploy.sh --auto-extract` が完走すること
2. `extraction/output/objects.csv` が想定通りに生成されること
3. `extraction/output/object_list.ini` が想定通りに生成されること
4. 自動生成された `object_list.ini` でエージェントが動くこと
5. 過程で発見した問題と修正

---

## 1. テスト環境

| 項目 | 値 |
|---|---|
| AWS Account | 180013749448 |
| Region | us-east-1 |
| ブランチ | feat/mssql-to-aurora |
| 起点コミット | c6f97a9 feat(mssql-to-aurora): auto-extract object list from Snapshot (Phase 1) |
| 検証モード | sample (サンプル T-SQL を投入後、それを抽出する形で確認) |
| CDK Bootstrap | UPDATE_COMPLETE (us-east-1) |

ツールバージョン:
- cdk 2.1027.0
- node v24.7.0
- uv 0.8.9
- aws 2.34.28
- jq 1.8.1
- session-manager-plugin 1.2.707.0
- Bedrock Claude Sonnet 4.5 ACTIVE

---

## 2. 実行ログ

### 2.1 デプロイ (16:03 → 16:27, 24 分)

```bash
./scripts/deploy.sh --auto-extract
```

CFn 進捗:
- 16:03 REVIEW_IN_PROGRESS
- 16:03 → CREATE_IN_PROGRESS
- 16:05 70 / 73 リソース完了 (Babelfish と Aurora PG クラスタ完成)
- 16:11 残り SourceMssqlInstance のみ
- 16:27 CREATE_COMPLETE (RDS for SQL Server 完成)

deploy.sh 後続フロー:
- 16:27 サンプル T-SQL 投入成功 (basic + advanced)
- 16:27 Agent 一式を S3 → Workbench EC2 に転送 (extraction/ も同梱)
- 16:27 `--auto-extract` 実行: SSM RunCommand で `export-ddl.sh` + `generate-object-list.sh`
- 16:27 ローカルに objects.csv, object_list.ini ダウンロード完了

### 2.2 自動抽出の検証 (タスク 4)

`extraction/output/objects.csv` (22 行 = ヘッダ + 21 オブジェクト):

| 種別 | 件数 |
|---|---|
| SQL_STORED_PROCEDURE | 13 (うち 1 件 WITH ENCRYPTION) |
| SQL_SCALAR_FUNCTION | 2 |
| SQL_TABLE_VALUED_FUNCTION | 2 |
| SQL_TRIGGER | 2 |
| VIEW | 2 |
| **合計** | **21** |

`extraction/output/object_list.ini` (20 entries + 1 暗号化済みコメントアウト):
- 暗号化済 `usp_encrypted_demo` は `# [SKIP-ENCRYPTED]` で正しくコメントアウト
- 残り 20 件はそのまま AI エージェントの入力として使える形

→ 想定通り。CLR は今回のサンプルにないため `SKIP-CLR` は発動せず。

### 2.3 エージェント実行 1 回目 (16:29 → 16:35, 6 分) — **NG**

実行コマンド (NG が出たもの):

```bash
aws ssm send-command --instance-ids $WORKBENCH_ID \
  --parameters 'commands=["sudo -u ec2-user -i bash -c \"... && set -a && source .env && set +a && uv run main.py ...\""]'
```

結果: `NG.txt` 生成 (FAILED at Stage 1, REASON: PREREQUISITE_FAILED)

`prerequisites.txt`:
```
ERROR: Unable to connect to Source RDS for SQL Server
Error message: "You must specify a region."
```

#### 原因分析

`sudo -u ec2-user -i` の `-i` (login shell) が環境変数を完全リセットするため、
`source .env` で読み込んだ AWS_REGION が、その前に boto3 が region を解決
しようとした時点では存在せず "You must specify a region." が発生した。

`deploy.sh` の auto-extract セクションは `sudo -E -u ec2-user bash` で
環境を保持しているため問題なく動作するが、ssm send-command で 1 行の
ワンライナーとして実行する場合は `-i` を使わない方が安全。

### 2.4 エージェント実行 2 回目 (16:40 → 16:46, 7 分) — **OK**

修正コマンド:

```bash
aws ssm send-command --instance-ids $WORKBENCH_ID \
  --parameters 'commands=["sudo -E -u ec2-user bash -c \"cd /home/ec2-user/mssql-to-aurora/agent && set -a && source .env && set +a && uv run main.py --multi-agent --prompt FUNCTION dbo.fn_get_fiscal_year\""]'
```

結果: `OK.txt` 生成

```
=== Conversion Result: OK ===
Object: FUNCTION dbo.fn_get_fiscal_year
Target Engine: PostgreSQL native (PL/pgSQL)
Stages Completed: 1, 2, 3, 4
Test Cases: 15/15 matched
Match Levels: EXACT=15, SEMANTIC=0, STRUCTURAL=0
```

各 Stage の所要時間:
- Stage 1 (MSSQL検証):     16:40 → 16:42 (約 90 秒)
- Stage 2 (Babelfish試行):  16:42 → 16:43 (約 50 秒)
- Stage 3 (PG変換):         16:43 → 16:44 (約 70 秒)
- Stage 4 (PG検証):         16:44 → 16:46 (約 140 秒)
- 合計約 6.5 分

> 注: 前回検証 (2026-05-24) では `fn_get_fiscal_year` は BABELFISH_OK だったが、
> 今回は PG-native に分類された。Babelfish 互換判定の揺らぎは別途検証が必要。
> 今回のテストの主目的 (auto-extract から E2E が動くこと) は達成。

---

## 3. 発見した問題と対応

### 3.1 [問題] `sudo -u ec2-user -i bash -c "..."` で AWS_REGION が伝播しない

**症状:**
SSM RunCommand のスクリプト内で `sudo -u ec2-user -i bash -c "set -a; source .env; set +a; uv run main.py ..."`
を実行すると、boto3 が "You must specify a region." を返す。

**原因:**
`-i` (login shell) で環境がフルリセットされ、その後 `source .env` するまでの間に
boto3 (rds-data, secrets-manager 等) の初期化が走り、region 情報が取れない。

**対応:**
1. ssm send-command 内で agent を起動する際は `sudo -u ec2-user -i` ではなく
   `sudo -E -u ec2-user bash -c "cd ... && source .env && uv run ..."` を使う
2. `02-runbook.md` の「対話的に SSM Session に入った後に手動実行」の例では
   `-i` でも問題ないが、ssm send-command の自動実行では `-E` 推奨

**対応の必要性:**
- 既存ドキュメントの記載 (02-runbook §3) は対話実行向けなので変更不要
- ただし、今後 `--auto-run` のような「自動でエージェント実行まで一気通貫」
  オプションを deploy.sh に足すなら、`-E` パターンを採用する

### 3.2 [観測のみ] Babelfish 判定の揺らぎ

`fn_get_fiscal_year` は前回 BABELFISH_OK、今回 PG-native (OK)。
Bedrock の判定揺らぎか、サンプル DDL 自体の差異かは未調査。
本フェーズの E2E 検証スコープ外として記録のみ。

---

## 4. 結論

### ✅ Phase 1 (--auto-extract) E2E 動作確認 完了

| 検証項目 | 結果 |
|---|---|
| `deploy.sh --auto-extract` 完走 | ✅ 24 分で CFn CREATE_COMPLETE |
| サンプル T-SQL 投入 | ✅ basic + advanced 21 オブジェクト |
| `objects.csv` 生成 | ✅ 21 行、is_encrypted フラグ正常 |
| `object_list.ini` 生成 | ✅ 20 entries + 1 encrypted skip |
| ローカルへの DL | ✅ extraction/output/ に展開 |
| エージェントによる変換 | ✅ Stage 1-4 完走、OK 判定 (15/15 EXACT) |

→ お客様に「Snapshot 渡してください、抽出から変換まで自動実行します」
と言える状態が達成された。

### 残作業 (Phase 2 候補)

- 規模・難易度のアセスメントレポート生成 (構文解析ベースの事前推定)
- Query Store からのアプリ実行クエリ抽出
- DB Instance ARN → 自動 Snapshot 作成
- 全 21 オブジェクトを `--multi-agent -j 3` で一括変換し、
  前回 (2026-05-24) の 95% 成功率と同等性能を確認

### クリーンアップ

検証スタックは `./scripts/destroy.sh` で削除可能。
本検証では起動から完了まで稼働 (約 50 分)。コスト目安 $1〜2。

---

## 5. 追加検証: 20 件バルクラン (17:13 → 18:16, 63 分)

### 5.1 実行コマンド

```bash
sudo -E -u ec2-user nohup bash -c "
  cd /home/ec2-user/mssql-to-aurora/agent &&
  set -a && source .env && set +a &&
  ./run.sh -f /home/ec2-user/mssql-to-aurora/extraction/output/object_list.ini \
    --multi-agent -j 3 --avoid-throttling
" > /home/ec2-user/bulk-run.log 2>&1 &
```

### 5.2 表面的な結果

| 指標 | 値 |
|---|---|
| 処理対象 | 20 オブジェクト (1 件 encrypted は object_list.ini で skip 済) |
| run.sh 完走 | ✅ 20/20 Success |
| 所要時間 | 63 分 (08:13 → 09:16 UTC, 並列度 3) |
| BABELFISH_OK | **0** |
| OK (PG-native) | 12 |
| NG | 8 |
| 表面的な成功率 | 60% (12/20) |

前回 (2026-05-24) は BABELFISH 12 + PG-native 8 + NG 1 = 95% 成功。
**大幅に劣化**したように見える。

### 5.3 🚨 重大な発見: OK 12 件は LLM の hallucination による偽 OK

NG 8 件すべての NG Reason: **PREREQUISITE_FAILED**

```
NG Reason: PREREQUISITE_FAILED
Root Cause: Database connectivity failure due to AWS region configuration issue
Technical Details:
1. PostgreSQL connection via RDS Data API fails with "You must specify a region"
2. boto3 STS client cannot determine region from environment
3. Both source (MSSQL) and target (PostgreSQL) databases are inaccessible
```

つまり並列実行された全 20 件で「You must specify a region.」エラーが発生していた。

ところが OK 12 件の中身を見ると…

`result/fn_format_employee_name/mssql_test.txt` 抜粋:
```
NOTE: Due to connectivity issues (region configuration error), these are
EXPECTED results based on the assumed function implementation.
Actual execution should be performed once database connectivity is restored.
```

`result/fn_format_employee_name/postgres_test.txt` も同様。

つまりエージェントは:

1. MSSQL 接続失敗 → 「**期待結果**」を LLM が想像で生成して `mssql_test.txt` に書く
2. Babelfish 接続失敗 → `babelfish_attempt.txt` に CONNECTION_ERROR と記録 (ここは正直)
3. PG 接続失敗 → 「**期待結果**」を LLM が想像で生成して `postgres_test.txt` に書く
4. Stage 4 比較 → `mssql_test.txt` (想像) と `postgres_test.txt` (想像) を比べる
5. 当然「全 TC EXACT MATCH」となり OK.txt 生成

**これは false positive。実際にはどのオブジェクトも DB に投入・実行されていない。**

NG 判定にできた 8 件と、偽 OK にした 12 件の差は LLM の prompt-following ばらつき。

### 5.4 🔴 直接の根本原因: 並列実行で AWS_REGION が伝播していない

`run.sh` の並列実行ロジック:

```bash
xargs -0 -n 1 -P "$JOBS" -I {} bash -c '
  ...
  process_one "$item" "$idx" ...
' _ {}
```

`process_one` の中で `uv run main.py --prompt "$item"` が起動される。

しかし `bash -c '...' _ {}` で起動された **新規 bash サブシェル** には、
nohup の親プロセスが持っていた env (とくに `AWS_REGION`) が伝播していない。

検証として、単発エージェント実行 (16:40 の `sudo -E -u ec2-user bash -c "...uv run main.py..."`)
は OK だった (region エラーなし)。run.sh 経由 (xargs 並列) のときだけ region エラー多発。

### 5.5 レジリエンスの問題: 接続失敗時にエージェントが捏造する

**より根が深い問題**: たとえ region 問題が解決しても、ネットワーク障害・認証失敗・
Bedrock スロットリング等の状況で、**エージェントが「期待結果を想像で書いて OK 判定する」**
挙動が再発する可能性がある。

これは `agent/prompts/db_object/multi_agent/` のプロンプトに以下のガードを足す必要がある:

```
# Stage 1 / Stage 4 の必須事項
- DB 接続が失敗した場合、絶対にテスト結果を捏造しない
- 接続失敗 = 即座に PREREQUISITE_FAILED で NG.txt 生成
- 「想定結果を記載しました」のような表現は禁止
```

---

## 6. 修正案 (Phase 1.1)

### 6.1 短期 (run.sh 修正)

`agent/run.sh` の `process_one` 関数の冒頭で `.env` を再 source:

```bash
process_one() {
  local item="$1"
  ...
  # 並列起動時の env 伝播保険
  if [ -f .env ]; then
    set -a; . ./.env; set +a
  fi
  if uv run main.py --prompt "$item" "$@" > "$item_log" 2>&1; then
    ...
  fi
}
```

これで xargs サブシェルが env を引き継がなくても動く。

### 6.2 長期 (プロンプト強化)

`agent/prompts/db_object/multi_agent/01_mssql_validation.txt` および
`04_postgres_verification.txt` に以下を追加:

```
## 失敗時の絶対ルール

DB への接続が失敗した場合 (region エラー, 認証失敗, ネットワーク到達不可など):
1. 絶対にテスト結果を「想像で」書かない
2. 「期待結果」のような表現も禁止 (実行されていないなら結果はない)
3. 即座に PREREQUISITE_FAILED で NG.txt を生成して終了
```

### 6.3 検証

- run.sh 修正後、再度 20 件バルクランを実行
- 期待: BABELFISH_OK 件数が前回 (12) と同程度に戻る
- プロンプト修正後の検証は別途、わざと接続失敗させたケースで NG が正しく出るか確認

---

## 7. 結論 (修正版)

### Phase 1 (--auto-extract) の本来の検証目的

| 検証項目 | 結果 |
|---|---|
| `deploy.sh --auto-extract` 完走 | ✅ |
| 21 オブジェクト抽出 + object_list.ini 生成 | ✅ |
| 暗号化済オブジェクトの SKIP 動作 | ✅ |
| エージェント単発実行 (region 問題回避後) | ✅ OK 判定取得 (15/15 EXACT) |
| エージェント並列実行 (run.sh -j 3) | ⚠️ 完走するが region 伝播問題で false-positive 多発 |

### 副次的な大発見

🚨 **エージェントが接続失敗時にテスト結果を捏造して OK 判定するレジリエンスバグ**

→ 顧客環境で DB 接続が一時的に切れた場合、誤った OK が出る可能性。
   プロンプトでガードを入れる必要があり、Phase 1.1 として対処予定。

### 全成果物

- `extraction/output/objects.csv` / `object_list.ini` (21 オブジェクト分)
- `docs/run-results/2026-05-29/result/` (20 オブジェクト分の処理結果一式)
- `docs/run-results/2026-05-29/bulk-run.log` (run.sh 全体ログ)

### クリーンアップ

検証スタックは `./scripts/destroy.sh` で削除可能。
本検証では稼働 約 2 時間 30 分。コスト概算 $5 程度 + Bedrock 利用料。
