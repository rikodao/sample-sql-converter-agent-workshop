# ADR-0001: ターゲットエンジン選定 — Babelfish と PG ネイティブを並行検証する

- ステータス: Accepted
- 日付: 2026-05-23
- 決定者: プロジェクトオーナー

## コンテキスト

RDS for SQL Server から Aurora PostgreSQL 系への移行で、ターゲットエンジンとして以下の選択肢がある:

1. **Aurora PostgreSQL ネイティブ**（T-SQL を PL/pgSQL に変換）
2. **Aurora PostgreSQL with Babelfish**（T-SQL 互換層、コード改修最小）
3. **両方**

## 検討した選択肢

### 選択肢A: Aurora PostgreSQL ネイティブのみ
- Pros: PG 機能フル活用、長期 TCO 低、運用ノウハウ流用可
- Cons: T-SQL → PL/pgSQL の人手 or LLM 変換コスト大、アプリ改修必須

### 選択肢B: Babelfish のみ
- Pros: アプリ改修最小、TDS ドライバそのまま、移行スピード速い
- Cons: 一部 T-SQL 機能非対応、PG 機能が透過的にアクセスしにくい、Babelfish 層の制約に縛られる

### 選択肢C: 両方を試して振り分ける ⭐ 採用
- Pros: 各オブジェクト単位で最適なターゲットを選べる、Babelfish で済むものを最小工数で移し、難物だけ PL/pgSQL に変換できる
- Cons: 検証環境のコストが2倍、エージェントのパイプラインが複雑化

## 決定

**選択肢 C を採用**。理由:

1. 実プロジェクトでは「動くものは Babelfish、動かないものだけ PG ネイティブ」がコスト最適だが、**事前にどちらが動くか分からない**ためエージェントで両方試す価値がある
2. 検証段階での追加インフラコストは1日 +$8 程度であり、プロジェクト全体の人件費から見れば誤差
3. Babelfish 適合性のレポートが副産物として得られ、本番移行計画の精度が上がる
4. エージェントのマルチエージェント機能を拡張すれば自然に組み込める（Stage 2 を追加するだけ）

## 影響

- CDK に `target-aurora-pg` と `target-babelfish` の両方の Construct が必要
- マルチエージェントが 3 段階 → 4 段階に拡張（Babelfish試行を Stage 2 に挿入）
- 結果ディレクトリに `BABELFISH_OK.txt` というフラグファイルを追加
- 早期終了オプション (`--early-exit-on-babelfish`) で運用時のコスト最適化可能

## 代替案再評価のトリガー

- Babelfish のサポート機能が大幅変化した場合（例: ALL T-SQL 完全互換になった等）
- プロジェクトのスコープが純粋な「アプリ改修最小化」のみに絞られた場合（Babelfishのみで良くなる）
- 顧客が「将来 PG に完全に乗り換えたい」と明示した場合（PG-native のみで良くなる）
