# 05. テスト戦略

## 1. 基本方針

「**実行して結果を比較する**」ことを唯一の真実とする。LLM による変換結果が「構文として通る」だけでは不十分で、**MSSQL での実行結果 ≒ Babelfish or PG での実行結果** を比較・判定して初めて OK とする。

## 2. テストケース構成

各 DB オブジェクトについて、エージェントは以下を生成する:

```
result/<obj>/mssql_test.sql        # MSSQL用（Stage 1で生成）
result/<obj>/babelfish_test.sql    # Babelfish用（Stage 2、ほぼ同一）
result/<obj>/postgres_test.sql     # PG用（Stage 4、PL/pgSQL構文）
```

各 `*_test.sql` は次のセクションを含む:

```
1. SETUP    (テストデータ準備、一時テーブル作成)
2. EXEC     (対象オブジェクトを複数パターンで実行)
3. ASSERT   (結果を SELECT で出力)
4. CLEANUP  (一時テーブル DROP、副作用ロールバック)
```

## 3. テストパターンの選び方

エージェントが守るべき網羅基準:

| カテゴリ | 必須テストケース数 |
|---|---|
| **正常系**: 代表的な入力で期待通りの結果 | 最低3 |
| **境界値**: NULL、空文字、ゼロ、最大値、負値 | 最低3 |
| **例外系**: 不正入力で適切なエラー | 最低2 |
| **トランザクション**: ロールバック動作 | 該当時1 |
| **副作用**: INSERT/UPDATE/DELETE の件数・内容 | 該当時2 |

## 4. 比較判定ロジック（Stage 4）

`comparison_result.txt` に書き出す:

```
=== Object: PROCEDURE dbo.usp_xxx ===
Test Case 1 (normal_input_a):
  MSSQL:    [(1, 'A', 100), (2, 'B', 200)]
  Babelfish: [(1, 'A', 100), (2, 'B', 200)]    ✓ MATCH
  Postgres:  [(1, 'A', 100), (2, 'B', 200)]    ✓ MATCH

Test Case 2 (boundary_null):
  MSSQL:    NULL
  Babelfish: NULL                                ✓ MATCH
  Postgres:  NULL                                ✓ MATCH

Test Case 3 (datetime_precision):
  MSSQL:    2026-05-23 10:00:00.123
  Babelfish: 2026-05-23 10:00:00.123              ✓ MATCH
  Postgres:  2026-05-23 10:00:00.123000          ⚠ FORMAT_DIFF (許容)

=== Verdict ===
Babelfish: ✓ OK (3/3 match)
Postgres:  ✓ OK (3/3 match, 1 format-only diff)
```

### 4.1 比較レベル

| レベル | 内容 |
|---|---|
| `EXACT` | 完全一致（バイトレベル） |
| `SEMANTIC` | 値として等価（小数の表記揺れ、タイムスタンプの精度差等を吸収） |
| `STRUCTURAL` | 件数・カラム順・型カテゴリのみ一致 |

デフォルトは `SEMANTIC`。`STRUCTURAL` は比較困難なケース（カーソル系、メッセージ出力系）のフォールバック。

### 4.2 自動許容差分

以下は `SEMANTIC` レベルで「差分なし」とみなす:

- `DATETIME` の `.000` と `.000000` のサフィックス
- `0.5` と `.5` の表記揺れ
- 末尾空白のあり/なし（`CHAR(n)` 型由来）
- ORDER BY が指定されていないクエリの順序差（ソート後比較）

## 5. テストデータ管理

### 5.1 一時テーブル方針

エージェントは Stage 1 のテストで以下のいずれかを使う:

1. **一時テーブル** (`#tmp_xxx` / `pg_temp.tmp_xxx`): セッション終了で消える、推奨
2. **専用テストスキーマ**（`migration_test`）: クリーンアップ責任があるが、複雑な依存関係を作りやすい
3. **既存テーブルの活用**: SETUP 時に挿入した行を CLEANUP で削除（`SAVEPOINT` 推奨）

### 5.2 サンプルデータ

`tests/data/seed.sql` に共通の従業員管理ドメインのサンプルデータを定義:
- `employees`（100人）
- `departments`（10部門）
- `salaries`（履歴1000件）
- `bonuses`（年次500件）

各テストケースはこれらに対する CRUD で網羅性を確保。

## 6. OK/NG の最終判定基準

`Stage 4` の最後で `OK.txt` または `NG.txt` を作成する。

### OK.txt の作成条件
- 全テストケースが `EXACT` または `SEMANTIC` で一致
- 構文エラーが解決済み
- パフォーマンス劣化が許容範囲（オプション）

### NG.txt の作成条件
- いずれかのテストが結果不一致
- エージェントが規定回数以内（デフォルト3回）に修正できなかった
- 変換不可能と判定された

NG.txt の中身:
```
NG Reason: [Category]
- Failed Test Case: <name>
  Expected: <MSSQL result>
  Actual:   <PG result>
  Diff:     <diff summary>
- Suspected Cause: <human-readable hypothesis>
- Recommended Action: <next step>
```

## 7. 既知の差異と対応

| 差異 | 例 | 対応方針 |
|---|---|---|
| `IDENTITY` 値が異なる | MSSQL: 1,2,3 / PG: 100,101,102 | 値そのものではなく**順序・件数**で比較 |
| エラーコード番号 | MSSQL: 50000 / PG: 22023 | カテゴリ（USER_ERROR等）で比較 |
| エラーメッセージ文言 | 言語・フォーマット異なる | メッセージ正規表現マッチで OK |
| `GETDATE()` の戻り | 実行時刻 | 比較除外（テストケース内で固定値使用を推奨） |
| 浮動小数 IEEE 754 端数 | `0.1 + 0.2` の表現差 | 比較精度を 6桁 に丸めて比較 |
| `NULL` ソート順 | MSSQL: NULLs first / PG: NULLs last | `NULLS FIRST` を明示 |

## 8. 性能テスト（オプション）

検証フェーズの初期版ではスコープ外。本番移行直前のベンチに含める。

エージェントが収集できる指標（取れれば）:
- `EXPLAIN ANALYZE` の Total Time
- `STATISTICS IO` 相当の論理読み込み数
- 実行時間（壁時計）

## 9. テスト失敗時のリトライ

`Stage 4` のリトライポリシー:

| 試行 | 動作 |
|---|---|
| 1回目 | テスト失敗 → エラー内容を `postgres.sql` 修正のヒントとして再変換依頼 |
| 2回目 | 再テスト失敗 → エラーパターン辞書から類似ケースを参照 |
| 3回目 | 再テスト失敗 → NG.txt を作成し終了 |

各試行のログは `result/<obj>/retry_log.txt` に追記される。

## 10. 全体メトリクス

`uv run python -m utils.summarize_results` の出力例:

```
=== Migration Coverage Report ===
Total objects:                42
  Babelfish OK:               18 (43%)
  PG-native OK:               21 (50%)
  Failed (NG):                  3 (7%)

=== Failure Categories ===
  Cursor + dynamic SQL:        2
  WITH ENCRYPTION (manual):    1

=== Average Conversion Time ===
  MSSQL → Babelfish:    1m 12s
  MSSQL → PG-native:    3m 45s
```
