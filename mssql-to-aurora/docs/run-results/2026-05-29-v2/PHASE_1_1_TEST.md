# Phase 1.1 修正後 E2E 再検証レポート (2026-05-30)

## 0. このレポートの目的

[2026-05-29 のテスト](../2026-05-29/AUTO_EXTRACT_TEST.md) で発見した 2 つのバグを
修正した上で、再度 20 件バルクランを実施し、修正効果を確認する。

修正対象:
1. `agent/run.sh` の `process_one` 冒頭で `.env` を再 source
2. `agent/prompts/db_object/multi_agent/01-04` に「接続失敗時の捏造禁止」絶対ルール追加

---

## 1. 修正内容

### 1.1 run.sh への `.env` 再 source 追加

`process_one` 関数の冒頭で `.env` を再読み込みすることで、xargs/bash -c 並列実行時の
env 伝播保険とした。

```bash
process_one() {
  ...
  if [[ -f .env ]]; then
    set -a
    . ./.env
    set +a
  fi
  ...
}
```

### 1.2 プロンプトに「接続失敗時の捏造禁止」ルール追加

4 つの multi-agent プロンプトすべてに、強い文言で禁止事項を追加:

- `01_mssql_validation.txt`: mssql.sql / mssql_test.txt の捏造禁止
- `02_babelfish_attempt.txt`: BABELFISH_OK.txt の捏造禁止
- `03_postgres_conversion.txt`: postgres.sql の推測作成禁止
- `04_postgres_verification.txt`: **OK.txt 作成の前提条件を明記**、過去事例 (12件偽 OK) も記載

`04` の例:
```
OK.txt を作成できる条件は **以下を全て満たした場合のみ**:

1. ✅ mssql_test.txt が **実 SQL Server で実行された結果**として存在する
2. ✅ postgres_test.sql を **実 Aurora PostgreSQL に投入して実行**できた
3. ✅ postgres_test.txt が **実 Aurora PostgreSQL での実行結果**として存在する
4. ✅ 全 TC が EXACT または SEMANTIC で一致

以下のいずれかに該当する場合は、絶対に OK.txt を作成してはならない:
- ❌ Stage 1 の成果物 (mssql_test.txt) が無い、または「expected results」のような捏造である
- ❌ ツール呼び出しが失敗して、postgres_test.txt を実 DB から取得できていない
- ❌ 「Due to connectivity issues」「expected」「assumed」などの捏造マーカーがある
- ❌ 「コードを読んで論理的には一致する」という推論だけで OK 判定を出す
```

---

## 2. 再バルクラン結果 (20 件 × 3 並列)

実行: 22:09:43 → 22:29:24 UTC (**約 20 分**, v1 の 63 分から大幅短縮)

| 区分 | v1 (修正前) | v2 (修正後) |
|---|---|---|
| 所要時間 | 63 分 | **20 分** |
| BABELFISH_OK | 0 | 0 |
| OK (PG-native) | **12 (うち全て偽 OK)** | **0 ✅** |
| NG | 8 | **20 ✅** |
| 偽 OK 件数 | **12** | **0 ✅** |
| `mssql.sql` 捏造件数 | 多数 | **0 ✅** |

### 2.1 ✅ 達成した成果

🎯 **偽 OK 撲滅** — v1 で 12 件あった「LLM が想像で結果を書いて OK 判定」が **完全にゼロ** になった

🎯 **`mssql.sql` 捏造ゼロ** — `find result -name mssql.sql | wc -l` = **0**。
   接続失敗時に勝手に DDL を書く挙動が完全に止まった

🎯 **NG.txt の理由が一貫** — 20 件の Failed At 集計:
   - Stage 1: 17 件 (DDL 取得失敗で正しく早期終了)
   - Stage 4: 3 件 (前ステージ成果物不足を正しく検出)

### 2.2 ⚠️ 未解決の課題

❌ **DB 接続はできているのに、Stage 1 が完了と判断されない**

run-logs を grep すると **17 件の log に `Executing on MSSQL: SELECT ...` が記録**されている。

```bash
$ grep -l "Executing on MSSQL: SELECT" run-logs/run-*.log | wc -l
17
```

つまり実際には MSSQL に SQL が投げられている。しかし NG.txt には:

```
ERROR DETAILS:
Failed to connect to Source RDS for SQL Server.
Error: "You must specify a region."
```

と書かれている。これは以下のいずれかが起きていると推測される:

1. **ツール呼び出しの一部 (例: 2 回目以降の SELECT) で region エラー**
   → MCP server プロセスが env を保持しないか、boto3 のクライアント再生成で region が消える
2. **LLM の判定ミス**: 1 度目の SELECT は成功したが、後続の処理で何か失敗があり、
   それを「region エラー」とまとめて書いた
3. **MCP server 起動時に env が渡っていない** (main.py の env propagation 部分)

決定的な調査には Workbench 上で env をログ出力する追加デバッグが必要。
本フェーズでは時間とコストの制約上 Phase 1.2 として残す。

---

## 3. 評価

### 3.1 Phase 1.1 の主目標達成度

| 目標 | 結果 |
|---|---|
| 並列実行時の env 伝播解決 | ❌ run.sh 修正だけでは不十分 (別箇所に問題あり) |
| エージェントの捏造防止 | ✅ **完全達成** (偽 OK 12→0, mssql.sql 多数→0) |

### 3.2 顧客視点での意味

- **修正前**: 顧客環境で接続障害があると **誤った OK 判定を多数出してしまう** → 重大事故リスク
- **修正後**: 接続障害時は **必ず NG として可視化**、顧客が「何件失敗したか」を正確に把握できる

→ 偽 OK 撲滅は **顧客信頼性の観点で最も重要な修正**。env 伝播は Phase 1.2 で対処。

---

## 4. Phase 1.2 で着手すべきこと

### 4.1 env 伝播問題の真因究明 (高優先)

調査ステップ:
1. Workbench EC2 で `uv run python -c "import os; print(os.environ.get('AWS_REGION'))"` を直接実行 → main.py 起動時の env を確認
2. `main.py` で `os.environ` を log にダンプ → MCP server に渡される env を確認
3. 必要なら `BedrockModel` / 各 MCP server の boto3 クライアントで明示的に region を指定

### 4.2 LLM の判定揺らぎの追加調査

たとえ env 問題が解決しても、Stage 1 で 1 つのツール呼び出しが失敗しただけで
全体を「失敗」と判断してしまう挙動はあり得る。`partial_failure` を許容する
ロジックがプロンプトに必要かもしれない。

---

## 5. 成果物

- `result/` (20 オブジェクト分の処理結果一式)
- `bulk-run-v2.log` 相当のログ (S3 に保存、必要なら DL 可)

---

## 6. クリーンアップ

修正と検証が完了したため、検証スタックは `./scripts/destroy.sh` で削除。
本フェーズの稼働時間: 約 18 時間 (前日のテスト含む) → コスト累計約 $10〜15。
