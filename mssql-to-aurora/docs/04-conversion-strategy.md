# 04. 変換戦略: Babelfish vs PostgreSQL ネイティブ

## 1. なぜ両方を試すか

| 観点 | Babelfish | PG ネイティブ (PL/pgSQL) |
|---|---|---|
| **アプリ改修** | ほぼ不要（TDSドライバそのまま） | コネクション・SQL文の改修必要 |
| **T-SQL 互換性** | 高（限定的な非対応あり） | 低（人 or LLM による変換が必須） |
| **PG 機能フル活用** | 不可（Babelfish層で抽象化） | 可（JSONB, GIN, FDW, 拡張等） |
| **長期 TCO** | 中（Babelfishメンテ依存） | 低（標準PG運用） |
| **学習コスト** | 低 | 中〜高 |

→ 「動くなら Babelfish、ダメなら PL/pgSQL」**の段階的判定**が最もコスト効率が良い。

## 2. 4段階パイプラインの設計思想

```
入力: PROCEDURE dbo.usp_xxx
  │
  ▼
┌─────────────────────────────────────┐
│ Stage 1: MSSQL検証                    │
│  - 対象オブジェクトのDDL取得          │
│  - 依存オブジェクト確認              │
│  - テストケース作成・実行            │
│  - Oracle時代の "正解の動作" を作る    │
└─────────────────────────────────────┘
  │ mssql.sql, mssql_test.txt
  ▼
┌─────────────────────────────────────┐
│ Stage 2: Babelfish試行                │
│  - mssql.sql をTDS:1433にそのまま投入  │
│  - 構文OKなら同等テストを実行         │
│  - 結果が一致すれば BABELFISH_OK     │
└─────────────────────────────────────┘
  │ 失敗時のみ
  ▼
┌─────────────────────────────────────┐
│ Stage 3: PG変換                       │
│  - T-SQL → PL/pgSQL 変換             │
│  - PG ネイティブ環境で構文チェック    │
└─────────────────────────────────────┘
  │ postgres.sql
  ▼
┌─────────────────────────────────────┐
│ Stage 4: PG検証                       │
│  - PG用テストを生成・実行             │
│  - MSSQL結果と比較                   │
│  - OK.txt / NG.txt                  │
└─────────────────────────────────────┘
```

**早期終了**: Stage 2 で Babelfish が成功すれば 3〜4 をスキップできる（フラグで制御）。これは**実コスト・LLMトークン削減**のため極めて重要。

## 3. Babelfish 適合性の判定基準

Stage 2 のエージェントは以下を機械的に確認する:

| チェック項目 | 判定 |
|---|---|
| `CREATE PROCEDURE/FUNCTION/TRIGGER` 構文が通る | OK |
| 参照するシステムオブジェクト（`sys.dm_*`, `INFORMATION_SCHEMA`）が Babelfish でサポート済 | OK |
| 全テストケースが MSSQL と同じ結果を返す | OK |
| エラーハンドリング（`TRY...CATCH`, `THROW`, `RAISERROR`）が期待通り動く | OK |
| 上記いずれかが NG | Stage 3/4 へ |

### 3.1 Babelfish が苦手とする領域（既知）

2026年5月時点での主な非対応・部分対応:

| 機能 | 状況 |
|---|---|
| CLR アセンブリ | 非対応（PL/pgSQL or 拡張で代替） |
| Service Broker | 非対応 |
| Linked Server | 限定対応（FDW で代替） |
| `sp_executesql` の動的 SQL | 多くのケースで動くが OUTPUT パラメタに制約 |
| 一部の DMV (`sys.dm_exec_*`) | 部分対応 |
| `MERGE` 文 | 対応（ただし PG 側の MERGE と微妙な差異あり） |
| `DATETIME2`, `DATETIMEOFFSET` の精度 | 対応（注意点あり） |
| `XML` データ型 | 対応 |
| `HIERARCHYID` | 対応 |
| `GEOGRAPHY` / `GEOMETRY` | 対応（PostGIS背景） |
| `IDENTITY` の挙動 | 対応（連番管理は別物） |
| `ROWVERSION` / `TIMESTAMP` | 対応 |
| `OUTPUT INTO` 句 | 対応 |
| カーソル（特に FAST_FORWARD） | 対応（性能差注意） |

エージェントには上記カテゴリの「失敗パターン辞書」を Stage 2 のプロンプトに入れて、**何を見れば良いか**を理解させる。

## 4. T-SQL → PL/pgSQL 主要変換ルール（Stage 3）

`agent/prompts/common/conversion_rules_tsql.txt` に集約。代表例:

| T-SQL | PL/pgSQL |
|---|---|
| `CREATE PROCEDURE x AS BEGIN ... END` | `CREATE OR REPLACE PROCEDURE x() LANGUAGE plpgsql AS $$ BEGIN ... END $$` |
| `DECLARE @v INT = 0` | `DECLARE v INT := 0;`（DECLAREブロックに集約） |
| `SET @v = ...` | `v := ...;` |
| `IF @v = 1 BEGIN ... END` | `IF v = 1 THEN ... END IF;` |
| `WHILE @v < 10` | `WHILE v < 10 LOOP ... END LOOP;` |
| `PRINT 'msg'` | `RAISE NOTICE 'msg';` |
| `RAISERROR('msg', 16, 1)` | `RAISE EXCEPTION 'msg';` |
| `TRY...CATCH` | `BEGIN ... EXCEPTION WHEN OTHERS THEN ... END;` |
| `IDENTITY(1,1)` | `GENERATED ALWAYS AS IDENTITY` or `serial` |
| `GETDATE()` | `now()` / `current_timestamp` |
| `ISNULL(a, b)` | `COALESCE(a, b)` |
| `LEN(s)` | `length(s)` |
| `CHARINDEX(p, s)` | `position(p in s)` |
| `SUBSTRING(s, n, m)` | `substring(s from n for m)` |
| `CAST(x AS DATE)` | `x::date` |
| `TOP n` | `LIMIT n` |
| `WITH (NOLOCK)` | （削除）or `READ UNCOMMITTED` トランザクション |
| `MERGE` | `INSERT ... ON CONFLICT DO UPDATE` |
| `OUTPUT INSERTED.*` | `RETURNING *` |
| `UPDATE t SET ... FROM t JOIN ...` | `UPDATE t SET ... FROM other WHERE ...` |
| `EXEC dbo.usp_xxx` | `CALL public.usp_xxx()` |
| `SCOPE_IDENTITY()` | `RETURNING id INTO ...` 句 |
| `BEGIN TRAN ... COMMIT TRAN` | （関数内では暗黙、PROCEDUREでは `BEGIN; COMMIT;`） |
| `@@ROWCOUNT` | `GET DIAGNOSTICS rc = ROW_COUNT;` |
| `sp_executesql N'...', N'...', ...` | `EXECUTE 'SQL文' USING param1, param2;` |
| `DATEPART(yy, d)` | `extract(year from d)` |
| `DATEADD(dd, n, d)` | `d + n * interval '1 day'` |
| `DATEDIFF(dd, a, b)` | `b::date - a::date` |
| `STUFF / FOR XML PATH` (文字列連結) | `string_agg()` |
| `ROW_NUMBER() OVER (...)` | 同（PG も対応） |

## 5. データ型マッピング

| T-SQL | PostgreSQL ネイティブ | Babelfish (透過) |
|---|---|---|
| `INT` | `integer` | `INT` |
| `BIGINT` | `bigint` | `BIGINT` |
| `DECIMAL(p,s)` | `numeric(p,s)` | `DECIMAL(p,s)` |
| `MONEY` | `numeric(19,4)` | `MONEY` (Babelfish型として実装) |
| `BIT` | `boolean` | `BIT` (1bit型として実装) |
| `VARCHAR(n)` / `NVARCHAR(n)` | `varchar(n)` / `text` | `VARCHAR(n)` / `NVARCHAR(n)` |
| `CHAR(n)` / `NCHAR(n)` | `char(n)` | `CHAR(n)` |
| `TEXT` / `NTEXT` | `text` | `TEXT` (非推奨) |
| `DATETIME` | `timestamp` | `DATETIME` |
| `DATETIME2(p)` | `timestamp(p)` | `DATETIME2(p)` |
| `DATETIMEOFFSET` | `timestamptz` | `DATETIMEOFFSET` |
| `DATE` | `date` | `DATE` |
| `TIME(p)` | `time(p)` | `TIME(p)` |
| `UNIQUEIDENTIFIER` | `uuid` | `UNIQUEIDENTIFIER` |
| `VARBINARY(n)` / `IMAGE` | `bytea` | `VARBINARY(n)` / `IMAGE` |
| `XML` | `xml` | `XML` |
| `HIERARCHYID` | （拡張 or text） | `HIERARCHYID` |
| `ROWVERSION` | `bytea` + trigger | `ROWVERSION` |
| `SQL_VARIANT` | `text` + 型情報カラム | `SQL_VARIANT` |
| `TABLE` (TVP) | `record[]` or `composite type` | `TABLE` |

## 6. 振り分けロジック（人間によるレビュー観点）

エージェントが OK/NG を判定したあと、人間が最終確認すべきポイント:

| パターン | 推奨ターゲット |
|---|---|
| アプリ改修コスト > 移行コスト | Babelfish |
| 高頻度実行・性能要件厳しい | PG ネイティブ（PL/pgSQL の方がオプティマイザに優しい） |
| PG 拡張（pgvector, PostGIS等）を使いたい | PG ネイティブ |
| サードパーティ製 BI ツールが TDS でしか繋がらない | Babelfish |
| アプリが ORM で抽象化されており SQL 直書きが少ない | PG ネイティブ |
| Linked Server / Service Broker 多用 | 要再設計、どちらでも難しい |

## 7. 制限事項とエスケープハッチ

- **暗号化ストアド**: `WITH ENCRYPTION` のものは definition 取得不可 → 人間が原本を別途準備
- **Cursor + 大量データ**: PG では set-based に書き換える方が良い → エージェントに指示
- **動的SQL多用**: テスト困難 → エージェントは「変換結果の動的SQL文字列が同等であること」までを検証
- **CLR**: 全件人間対応。エージェントは検出と報告のみ
- **MERGE の細かい挙動差異**: 同一データで MSSQL と PG/Babelfish の結果テーブルを比較するテストケースを必ず生成
