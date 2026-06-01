# ADR-0002: ソース抽出方法 — Snapshot からのクローン RDS 経由

- ステータス: Accepted
- 日付: 2026-05-23

## コンテキスト

実 RDS for SQL Server からスキーマ・ストアド・関数・依存関係を抽出する手段は複数ある:

1. 本番 RDS に直接接続して抽出
2. RDS Snapshot を別 RDS インスタンスに復元してそこから抽出（クローン）
3. RDS Snapshot を S3 にエクスポート → EC2 上の SQL Server に復元
4. Read Replica を作成して抽出

また、ユーザーから「SCT が使えない」と言われていたが、正確には:
- SCT/DMS Schema Conversion 自体は MSSQL → PG をサポート
- ただし RDS for SQL Server の master ユーザーが sysadmin ではないため、SCT が要求する一部のシステム情報取得が制限される
- これにより複雑なストアド・トリガー・CLR が抽出から漏れるケースがある

## 検討した選択肢

### A. 本番 RDS に直接接続
- Pros: 追加リソース不要
- Cons: **本番への影響リスク**、SCT の sysadmin 制約で抽出漏れリスク
- 評価: ❌ 採用不可（本番に触るのを許容できない）

### B. Snapshot → クローン RDS ⭐ 採用
- Pros: 本番完全非破壊、本番と同じ RDS 環境（権限・互換性同一）、CDK で自動化しやすい
- Cons: SCT の sysadmin 制約は同じ（→ エージェント側で `sys.sql_modules` 直接クエリで補完）
- 評価: ✅

### C. Snapshot → S3 → EC2 上 SQL Server Developer に復元
- Pros: sysadmin 取得可能で SCT も完全動作、CLR 等もフル抽出可
- Cons: Native Backup に Option Group 設定 + S3 連携が必要、復元用 EC2 構築コスト、ライセンス考慮
- 評価: 🟡 必要時に B から切り替え可能（ADR-0005 で別途検討）

### D. Read Replica
- Pros: 軽量
- Cons: RDS for SQL Server の Read Replica は限定的、抽出のためだけに作るのは過剰
- 評価: ❌

## 決定

**選択肢 B を採用**（必要時に C に切り替え可能な構造で実装）。

理由:

1. **本番非破壊** が最優先要件
2. CDK の `DatabaseInstanceFromSnapshot` で実装が簡潔
3. SCT の制約はエージェントの `sys.sql_modules` 直接抽出で回避できる（むしろこれが本プロジェクトの存在意義）
4. CLR 等の抽出漏れは、エージェントが「抽出失敗」を検出して報告するロジックでカバー
5. C への移行はリストア手順の差し替えだけなので、後から拡張可能

## 影響

- CDK に `source-mssql.ts` Construct を作り、`sourceMode` context (`sample` | `snapshot`) で挙動を切替
- `sample` モード: 空の RDS を起動 → deploy.sh が `tests/ddl/sample_objects.sql` を投入
- `snapshot` モード: `DatabaseInstanceFromSnapshot` で復元、サンプル投入はスキップ
- `extraction/` ディレクトリは Snapshot モード時のみ意味を持つが、サンプルモードでも疎通検証には使える

## エスケープハッチ

CLR / WITH ENCRYPTION / 複雑な暗号化オブジェクトが多い場合は、選択肢 C への切り替えを検討する。その際は新規 ADR で記録。
