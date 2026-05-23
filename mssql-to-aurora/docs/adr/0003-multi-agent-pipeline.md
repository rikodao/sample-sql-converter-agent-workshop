# ADR-0003: マルチエージェントパイプラインを 4 段階構成にする

- ステータス: Accepted
- 日付: 2026-05-23

## コンテキスト

既存の Oracle → PostgreSQL 移行用エージェント（`agent/multi_agent_processor.py`）は 3 段階構成（Oracle検証 → PG変換 → PG検証）になっている。

MSSQL → Aurora 移行ではターゲットが 2 つあるため、同じパイプライン構造は使えない。

## 検討した選択肢

### A. 5段階（MSSQL検証 → Babelfish試行 → Babelfish検証 → PG変換 → PG検証）
- Pros: Babelfish の「試行」と「検証」を分離して責務が明確
- Cons: ステージが多く LLM 呼び出しコスト増、Babelfish 試行の中で簡易検証も可能なため過剰

### B. 4段階（MSSQL検証 → Babelfish試行(検証含む) → PG変換 → PG検証）⭐ 採用
- Pros: シンプル、Babelfish試行ステージで構文+実行+比較を一括処理、早期終了が自然
- Cons: Babelfish試行ステージの責務が若干重い

### C. 3段階×2回（MSSQL検証 → Babelfish | PG並列）
- Pros: 並列実行で時間短縮の可能性
- Cons: エージェント並列実行の複雑性、コスト増、結果統合ロジックが複雑、現フレームワークが直列前提
- 評価: 将来検討

### D. 既存3段階のまま、ターゲットをパラメタ化
- Pros: 既存コード再利用
- Cons: Babelfish試行の早期終了が表現できない、Babelfishと PG-native の比較分析が分断される

## 決定

**選択肢 B を採用**。

```
[1] MSSQL検証
[2] Babelfish試行 (構文+実行+比較を一括)
[3] PG変換          (Stage 2 失敗時のみ実行)
[4] PG検証          (Stage 2 失敗時のみ実行)
```

## 設計詳細

### Stage 2 の Babelfish試行で行うこと

1. `mssql.sql` を Babelfish の TDS:1433 にそのまま投入し、構文OKか確認
2. 失敗時は `babelfish_attempt.txt` に詳細記録、Stage 3 へ進む
3. 成功時は `babelfish_test.sql` を生成（基本的に `mssql_test.sql` のコピー）し実行
4. 結果を `babelfish_test.txt` に保存
5. `mssql_test.txt` と比較し、`SEMANTIC` レベルで一致すれば `BABELFISH_OK.txt` を作成
6. 不一致なら Stage 3 へ進む（PG-native も試す）

### 早期終了フラグ `--early-exit-on-babelfish`

デフォルト ON。Stage 2 で `BABELFISH_OK.txt` が作成されたら Stage 3/4 をスキップ。OFF の場合（`--always-validate-both`）両方検証して `comparison_result.txt` で比較レポート。

### 結果ファイルマトリクス

| ファイル | Stage 2 で OK | Stage 2 で NG → Stage 4 で OK | Stage 4 で NG |
|---|---|---|---|
| `mssql.sql` | ✓ | ✓ | ✓ |
| `mssql_test.txt` | ✓ | ✓ | ✓ |
| `babelfish_attempt.txt` | ✓ | ✓ | ✓ |
| `babelfish_test.txt` | ✓ | (試行のみ) | (試行のみ) |
| `BABELFISH_OK.txt` | ✓ | - | - |
| `postgres.sql` | (skip) | ✓ | ✓ |
| `postgres_test.txt` | (skip) | ✓ | ✓ |
| `comparison_result.txt` | (skip) | ✓ | ✓ |
| `OK.txt` | - | ✓ | - |
| `NG.txt` | - | - | ✓ |

## 影響

- `agent/multi_agent_processor.py` を MSSQL 用に新規実装（既存はOracleのまま温存）
- `agent/prompts/db_object/multi_agent/` に4つのプロンプトファイルを新設
- `agent/prompts/prompts.py` の `MultiAgent` クラスを 4-stage 対応に書き換え（MSSQL用）
- 既存の Oracle 用パイプラインには影響なし

## 拡張ポイント

- ステージを Skill として独立させると、Q Developer / 外部ツールから個別呼出可能
- 並列実行（選択肢 C）への移行時は、Stage 2 と Stage 3+4 を並列起動するだけ
- データ移行（DMS）と組み合わせる場合、Stage 5 として「データ整合性確認」を追加
