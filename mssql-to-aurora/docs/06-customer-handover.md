# 06. お客様向けハンドオーバー手順書

> [!NOTE]
> このドキュメントは **お客様 / アカウントマネージャ (AM) / ソリューションアーキテクト (SA) 向け**のハンドオーバー資料です。
> 開発者向けの詳細な技術 Runbook は [02-runbook.md](./02-runbook.md) を参照してください。

---

## 0. このドキュメントの読み方

| 役割 | 読むべきセクション |
|---|---|
| **お客様 (DB / アプリ担当)** | §1, §2, §3, §6, §8, §9 |
| **AM / 提案担当** | §1, §3, §6, §7, §8, §9 |
| **SA / 実行担当** | 全部 (実作業は §4, §5 中心) |

ペースの目安:

```
[Day 0]  キックオフ・ヒアリング (§3, §8)
   ↓
[Day 1]  事前準備・AWSアカウント整備 (§4)
   ↓
[Day 2-3] デプロイ・サンプル動作確認 (§4)
   ↓
[Day 4-N] 実オブジェクトの一括変換 (§5)
   ↓
[終週]   結果レポートの読み解き・移行計画策定 (§6, §7)
```

---

## 1. このツールでできること・できないこと

### ✅ できること

- **T-SQL ストアドプロシージャ / 関数 / トリガー / ビュー** を AI エージェントで Aurora PostgreSQL 系に変換
- **2 つの移行先**を自動振り分け
  - 🟢 **Babelfish (Aurora PG with TDS:1433)** — T-SQL のまま動くなら、これが最短・低リスク
  - 🟡 **Aurora PostgreSQL (PL/pgSQL ネイティブ)** — Babelfish で動かないものは PL/pgSQL に変換
- **実 DB に対するテストで結果を比較**し、OK / NG を機械判定
- 移行困難オブジェクトの **NG 理由を可視化**し、人手対応リストとして整理

### ❌ できないこと (現バージョン)

| 領域 | 理由 |
|---|---|
| **本番 DB に直接アクセス** | 設計思想として禁止。Snapshot からクローンを作って検証 |
| **テーブル / インデックス / 制約の DDL 移行** | 対象は手続き型オブジェクトのみ。テーブルは AWS DMS / SCT で別途実施 |
| **データ移行 (DML)** | 同上 |
| **`WITH ENCRYPTION` で保護された procedure** | T-SQL definition が取得不可なため、お客様側で平文ソースを別途提供してもらう必要あり |
| **CLR ストアド (.NET アセンブリ)** | Aurora PG では非サポート。再設計が必要 |
| **リンクサーバ / OPENQUERY / OPENROWSET** | クロス DB アクセスの再設計が必要 |
| **SQL Server Agent ジョブ** | EventBridge Scheduler / Lambda など別アーキで再構築 |
| **SSIS パッケージ** | AWS Glue / Step Functions など別アーキで再構築 |
| **Service Broker / DBMail** | SNS / SES / EventBridge で再構築 |
| **アプリ側のドライバ / 接続文字列改修** | PG ネイティブ移行時のアプリ修正は別作業 |

---

## 2. 全体アーキテクチャ (5行サマリ)

```
お客様 RDS SQL Server (Snapshot)
    ↓ コピー
検証用 RDS SQL Server (CDK で復元)
    ↓ AI Agent (Strands + Bedrock Claude Sonnet 4.5)
Aurora PG with Babelfish (TDS:1433)  または  Aurora PG ネイティブ (PL/pgSQL)
    ↓ テスト実行・結果比較
result/<obj>/{BABELFISH_OK | OK | NG}.txt
```

詳細図: [01-architecture.md](./01-architecture.md)

---

## 3. お客様に準備していただく情報

> [!NOTE]
> 本ツールは「**Snapshot を渡せば、オブジェクト一覧抽出から変換・検証まで自動実行**」を目指しています。
> お客様による手動でのオブジェクト名リストアップは **不要**です。

### 3.1 必須 — これがないと開始できません

| # | 項目 | 例 / 補足 |
|---|---|---|
| 1 | **検証専用 AWS アカウント** | PoC 専用のクリーンなアカウント。**弊社の IAM ユーザ/ロールに AdministratorAccess 相当の権限を付与**いただきます (CDK で VPC・RDS・EC2 を作成するため)。 |
| 2 | **利用リージョン** | **`us-east-1` 必須** (Bedrock Claude Sonnet 4.5 を使うため) |
| 3 | **対象 SQL Server の種別** | a) サンプルでデモ / b) お客様 RDS の Snapshot / c) オンプレ MSSQL → 別途エクスポート |
| 4 | **対象 DB 名** | Snapshot 内のどのデータベースを抽出対象にするか (例: `YourAppDb`) |

> [!IMPORTANT]
> **検証用アカウントの提供形態**は以下のいずれかをご選択ください:
> - **A. お客様提供アカウント (推奨)**: お客様側で PoC 用 AWS アカウントを用意し、
>   弊社作業者の IAM ユーザに AdministratorAccess を付与
> - **B. 弊社提供アカウント**: 弊社の検証用アカウントに Snapshot を共有・コピーいただく
>   (より厳格な隔離が必要な場合)
>
> どちらでも、本検証は **検証用アカウント内で完結**し、お客様の本番アカウントには
> 一切の操作を行いません。

### 3.2 Snapshot モード (b) を選んだ場合の追加項目

| # | 項目 | 例 / 補足 |
|---|---|---|
| 5 | **Snapshot ARN または ID** | 検証用アカウントにコピー済みのもの (詳細は §4.5 参照) |
| 6 | **元 DB のインスタンスクラス** | `db.m5.xlarge` 等。検証では同等以下のサイズで起動 |
| 7 | **SQL Server のバージョン / Edition** | 2019 Standard, 2022 Enterprise など |
| 8 | **Snapshot の暗号化 / KMS キー情報** | 暗号化済みなら **KMS キーも検証用アカウントへ共有が必要** (§4.5 参照) |
| 9 | **本番アカウント ID** | クロスアカウント Snapshot 共有許可時に必要 |
| 10 | **検証用アカウント ID** | 共有先として本番側に登録する ID |

> [!IMPORTANT]
> **オブジェクト名のリストアップは不要です**。Snapshot から復元した検証 DB に対して、弊側で `sys.objects` / `sys.sql_modules` を直接 SELECT して全件抽出します (詳細: [03-source-extraction.md](./03-source-extraction.md))。
>
> **Snapshot は事前にお客様側で「本番 → 検証用アカウント」へコピー済み**の状態でご提供ください (§4.5 に詳細手順)。本番アカウントへ弊社がアクセスすることは一切ありません。

### 3.3 任意だが、あると精度が上がる項目

| # | 項目 | 効果 |
|---|---|---|
| 10 | **Query Store の有効化状況** ⭐推奨 | 有効なら **過去のアプリ実行クエリの全量** が Snapshot から抽出可能 (本番非侵襲) → `queries.csv` 出力 |
| 11 | **既存テストデータ / 期待出力** | AI が生成するテストの精度補強 |
| 12 | **アプリ側の接続情報 (ドライバ / 接続文字列)** | Babelfish 維持 vs ネイティブ PG の判断材料 |
| 13 | **業務上の優先順位 (どの procedure から?)** | 全件は時間がかかるため、優先度高の N 件で先行検証 |
| 14 | **依存関係 (リンクサーバ / SQL Agent ジョブ等の有無)** | スコープ外作業の早期切り出し |

Query Store 有効化の確認方法:
```sql
SELECT name, is_query_store_on FROM sys.databases WHERE name = 'YourAppDb';
```

無効の場合の有効化 (本番側で事前に実施推奨、再起動不要・公式ベンチでオーバーヘッド <2%):
```sql
ALTER DATABASE [YourAppDb] SET QUERY_STORE = ON
    (OPERATION_MODE = READ_WRITE,
     QUERY_CAPTURE_MODE = AUTO,
     MAX_STORAGE_SIZE_MB = 2048,
     STALE_QUERY_THRESHOLD_DAYS = 30);
```

> [!IMPORTANT]
> Query Store が無効の場合、`queries.csv` は生成されません (本ツールは best-effort で skip し、デプロイは継続)。
> アプリ実行クエリの分析が必要なケース (コード資産だけでなく実呼出頻度や互換性事前評価まで行いたい場合) は、お客様 DBA に **Snapshot 取得前** の有効化をお願いしてください。

### 3.4 事前合意事項

```
□ 本番 DB には触れません (Snapshot からのクローンのみ操作)
□ 変換結果はあくまで「検証用」。本番投入前にお客様レビュー必須
□ 1 オブジェクトあたり 2〜5 分、Bedrock 利用料が発生 (§9 参照)
□ 検証で発生する Snapshot は手動削除が必要 (destroy 後も残存)
□ 自動変換できないオブジェクトは「人手対応リスト」として返却
```

§8 にコピペ可能なヒアリングシートを置いています。

---

## 4. 事前準備 (実行担当 / SA 作業)

### 4.1 ローカル環境

```
□ AWS CLI (認証情報セット済み)
□ AWS CDK + Node.js
□ uv (Python パッケージマネージャ)
□ Session Manager Plugin
□ jq
```

詳細インストール手順は [02-runbook.md §0, §1](./02-runbook.md) を参照。

### 4.2 AWS アカウント側

```
□ Bedrock コンソール → us-east-1 で Claude Sonnet 4.5 のモデルアクセス申請・承認済み
□ 必要に応じて Bedrock Sonnet 4.5 RPM 上限の引き上げ (デフォ 50 → 並列度 3 以上を狙うなら緩和申請)
□ CDK Bootstrap 済み (npx cdk bootstrap)
```

### 4.3 リポジトリ取得

```bash
git clone <repo-url>
cd mssql-to-aurora
git checkout feat/mssql-to-aurora   # 現在のブランチ
```

### 4.4 デプロイ

サンプルモード (まずデモ) の場合:

```bash
./scripts/deploy.sh
```

Snapshot モード + 自動抽出 (お客様案件で推奨) の場合:

```bash
./scripts/deploy.sh \
  --source-mode snapshot \
  --snapshot-id arn:aws:rds:us-east-1:<検証用アカウントID>:snapshot:<copied-id> \
  --instance-class db.m5.xlarge \
  --extract-database YourAppDb \
  --auto-extract
```

`--auto-extract` を付けると、デプロイ完了後そのまま:

1. Snapshot から検証 DB を復元
2. Workbench EC2 から検証 DB に接続して全オブジェクト抽出
3. `extraction/output/object_list.ini` (AI エージェント入力ファイル) をローカルにダウンロード

まで自動で進みます。所要時間 25〜35 分。

### 4.5 クロスアカウント Snapshot コピー (お客様作業)

> [!IMPORTANT]
> このセクションは **お客様側で事前に実施**いただく内容です。
> 本番アカウント → 検証用アカウントへ Snapshot をコピーしておくことで、
> 弊社 (検証用アカウント側) は本番アカウントに一切アクセスせず作業できます。

#### 4.5.1 全体フロー

```
┌─ 本番アカウント (お客様DBA) ────────────────────────┐
│  ① Snapshot 作成                                     │
│  ② Snapshot を検証用アカウントへ共有                  │
│  ③ (暗号化済み) KMS キーも検証用アカウントへ共有      │
└──────────────────────────────────────────────────────┘
                    │ 共有 (権限付与のみ)
                    ▼
┌─ 検証用アカウント (お客様/弊社) ─────────────────────┐
│  ④ Snapshot を「コピー」してアカウント内に取り込む    │
│     (これにより検証用アカウントでオーナー権を持つ)     │
│  ⑤ ARN を弊社へ共有                                  │
└──────────────────────────────────────────────────────┘
                    │
                    ▼
            ⑥ 弊社が deploy.sh --snapshot-id <copied-arn>
```

参考: [AWS 公式ドキュメント — DB クラスタースナップショットのクロスアカウントコピー](https://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/AuroraUserGuide/USER_CopyDBClusterSnapshot.CrossAccount.html)
(SQL Server / RDS DB Instance Snapshot の場合も同様の手順)

#### 4.5.2 ① 本番アカウントで Snapshot を作成 (既存があれば省略可)

```bash
# 本番アカウントの DBA が実行
aws rds create-db-snapshot \
  --region <prod-region> \
  --db-instance-identifier <prod-mssql-instance> \
  --db-snapshot-identifier <prod-mssql-instance>-for-poc-$(date +%Y%m%d)
```

完了後、Snapshot ARN を控える:
```
arn:aws:rds:<prod-region>:<本番アカウントID>:snapshot:<prod-mssql-instance>-for-poc-YYYYMMDD
```

#### 4.5.3 ② Snapshot を検証用アカウントへ共有

```bash
# 本番アカウントの DBA が実行
aws rds modify-db-snapshot-attribute \
  --region <prod-region> \
  --db-snapshot-identifier <prod-mssql-instance>-for-poc-YYYYMMDD \
  --attribute-name restore \
  --values-to-add <検証用アカウントID>
```

#### 4.5.4 ③ KMS キーの共有 (暗号化済み Snapshot の場合のみ)

暗号化済み Snapshot は **KMS キーも検証用アカウントへ共有が必要**です。
キーポリシーに以下を追加 (本番アカウント側 KMS):

```json
{
  "Sid": "Allow validation account to use the key",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::<検証用アカウントID>:root"
  },
  "Action": [
    "kms:Decrypt",
    "kms:DescribeKey",
    "kms:CreateGrant",
    "kms:Encrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*"
  ],
  "Resource": "*"
}
```

または CLI で:

```bash
aws kms create-grant \
  --region <prod-region> \
  --key-id <kms-key-id> \
  --grantee-principal arn:aws:iam::<検証用アカウントID>:root \
  --operations Decrypt DescribeKey CreateGrant Encrypt ReEncryptFrom ReEncryptTo GenerateDataKey GenerateDataKeyWithoutPlaintext
```

> [!WARNING]
> AWS マネージド KMS キー (`aws/rds`) は共有不可です。
> Snapshot を作成する際にカスタマー管理 KMS キー (CMK) を使うか、
> AWS マネージドキーから CMK へ再暗号化したコピーを作る必要があります。

#### 4.5.5 ④ 検証用アカウントで Snapshot をコピー

```bash
# 検証用アカウント側 (弊社作業者の IAM で) 実行可
# → us-east-1 (本検証で使うリージョン) に直接コピーする

# 暗号化されていない場合
aws rds copy-db-snapshot \
  --region us-east-1 \
  --source-db-snapshot-identifier arn:aws:rds:<prod-region>:<本番アカウントID>:snapshot:<prod-snapshot-id> \
  --target-db-snapshot-identifier mssql-poc-source-$(date +%Y%m%d) \
  --copy-tags

# 暗号化されている場合 (検証用アカウント内の CMK で再暗号化)
aws rds copy-db-snapshot \
  --region us-east-1 \
  --source-db-snapshot-identifier arn:aws:rds:<prod-region>:<本番アカウントID>:snapshot:<prod-snapshot-id> \
  --target-db-snapshot-identifier mssql-poc-source-$(date +%Y%m%d) \
  --kms-key-id alias/aws/rds  \
  --copy-tags
```

リージョン跨ぎが発生する場合 (本番=ap-northeast-1, 検証=us-east-1 等)、コピーには
**Snapshot サイズに応じて 30 分〜数時間**かかる場合があります。

#### 4.5.6 ⑤ 弊社へ ARN を共有

最終的に検証用アカウントに以下のような ARN ができます:
```
arn:aws:rds:us-east-1:<検証用アカウントID>:snapshot:mssql-poc-source-YYYYMMDD
```

これを弊社へ共有いただければ、§4.4 の `--snapshot-id` に渡してデプロイ開始できます。

#### 4.5.7 トラブルシュート

| 症状 | 原因 / 対処 |
|---|---|
| `KMSKeyNotAccessibleFault` | KMS キーポリシー (§4.5.4) を確認、grant を作り直す |
| `DBSnapshotNotFound` | 共有 (§4.5.3) ができていない、または検証アカウントで未コピー |
| `InvalidSnapshotState` | Snapshot が `available` 以外の状態 (creating/copying/incompatible-restore) |
| クロスリージョンコピーが遅い | 通常動作。完了まで待つ。サイズ目安: 100GB で約 30 分 |
| `aws/rds` (AWS マネージド KMS) で共有できない | カスタマー管理 KMS キーへ再暗号化が必要 (§4.5.4 警告参照) |

---

## 5. 実行 (一括変換)

### 5.0 そもそも対象 T-SQL はどう入力するのか?

このツールは「**T-SQL のソースコードをアップロードする**」のではなく、
「**対象オブジェクトの名前を指定すると、エージェントが Source SQL Server から
DDL を自動取得する**」設計です。

→ 対象オブジェクトが Source SQL Server (= Snapshot から復元した検証 DB) に
存在している必要があります。

| パターン | 入力経路 | 用途 |
|---|---|---|
| A. サンプルモード | `deploy.sh` が `tests/ddl/sample_objects.sql` を SSM RunCommand で自動投入 | デモ・ワークショップ |
| B. **Snapshot モード + `--auto-extract`** | `deploy.sh` が Snapshot から復元 → 全オブジェクト自動抽出 → `object_list.ini` 生成 | **実 DB 移行検証 (推奨)** |
| C. アドホック投入 | 個別 `.sql` を Workbench EC2 から `sqlcmd` で投入 | 単発検証・部分試行 |

### 5.1 対象オブジェクト一覧の取得 (パターン B の場合)

`--auto-extract` 付きでデプロイした場合、ローカルに以下が生成されます:

```
mssql-to-aurora/extraction/output/
├── objects.csv         # 全オブジェクト一覧 (type, schema, name, encrypted フラグ)
├── object_list.ini     # AI エージェント入力 (CLR / 暗号化はコメントアウト済)
└── queries.csv         # アプリ実行クエリ全量 (Query Store が有効なときのみ)
```

> [!NOTE]
> `queries.csv` は **Query Store が有効化されている場合のみ生成**されます。
> 無効の場合 best-effort でスキップされ、`objects.csv` と `object_list.ini` のみ出力されます。
> `queries.csv` には query_hash 集約形式で全ユニーククエリが含まれ、
> 実行頻度の低いオブジェクトの除外や、アプリ側 SQL の Babelfish 互換性事前評価に利用します。

中身を確認し、必要に応じて編集します:

```bash
cat extraction/output/object_list.ini
```

例:
```
# Auto-generated by extraction/scripts/generate-object-list.sh
PROCEDURE dbo.usp_calculate_employee_bonus
PROCEDURE dbo.usp_archive_old_orders
# [SKIP-ENCRYPTED] PROCEDURE dbo.usp_encrypted_demo (...)
FUNCTION dbo.fn_get_fiscal_year
TRIGGER dbo.trg_audit_employees
VIEW dbo.v_active_employees
```

行頭に `#` を付ければスキップ、外せば変換対象に追加できます。優先度の高いものだけ残すといった編集も可能です。

### 5.2 Workbench EC2 に接続して実行

```bash
# Workbench EC2 に SSM Session Manager で接続
aws ssm start-session --target $(jq -r '.MssqlToAuroraStack.WorkbenchInstanceId' output.json) --region us-east-1

# (EC2 内で) — agent ディレクトリへ
sudo -u ec2-user -i
cd ~/mssql-to-aurora/agent
set -a; source .env; set +a

# 自動抽出した object_list.ini を使う場合は、EC2 にコピーする
# (ローカル端末から S3 経由で送るか、--auto-extract で生成された
#  ~/mssql-to-aurora/extraction/output/object_list.ini を直接指定)
EXTRACTED=~/mssql-to-aurora/extraction/output/object_list.ini

# 一括変換 (3並列、推奨)
./run.sh --multi-agent -f $EXTRACTED -j 3
```

サンプルモードまたは独自 `object_list.ini` を使う場合:

```bash
# agent/object_list.ini を使う (デフォルト)
./run.sh --multi-agent -j 3
```

10 オブジェクトで 30〜60 分が目安。Bedrock スロットリング対策が必要なら `--avoid-throttling` を追加。

### 5.3 結果集計

```bash
uv run python -m utils.summarize_results > summary.md
cat summary.md
```

---

## 6. 結果の読み方

### 6.1 振り分けの 3 区分

| 区分 | 結果ファイル | 意味 | 次のアクション |
|---|---|---|---|
| 🟢 **Babelfish 互換** | `BABELFISH_OK.txt` | T-SQL のまま Babelfish で動く | アプリの接続先を Babelfish (TDS:1433) に向け替えるだけ |
| 🟡 **PG-native 移行成功** | `OK.txt` + `postgres.sql` | PL/pgSQL に変換し、テストで MSSQL と同一結果 | アプリの接続文字列を PostgreSQL に変更し `postgres.sql` をデプロイ |
| 🔴 **NG (失敗)** | `NG.txt` | AI 自動変換で対応不可 | 人手レビュー対象。CLR / リンクサーバ / 暗号化済み等が候補 |

### 6.2 サンプル実行結果 (参考: 21 オブジェクト)

直近の検証実行 ([SUMMARY.md](./run-results/2026-05-24/SUMMARY.md)) ではこのような結果でした。お客様への説明用にそのまま使えます:

| 指標 | 値 |
|---|---|
| 全オブジェクト数 | 21 |
| 🟢 Babelfish 互換 | 12 (57%) |
| 🟡 PG-native 移行 | 8 (38%) |
| 🔴 失敗 | 1 (5%) |
| **総合成功率** | **95%** |
| テスト通過率 | 88/88 (100%) |

### 6.3 移行工数換算 (簡易目安)

| カテゴリ | 1件あたり | 内訳 |
|---|---|---|
| 🟢 Babelfish 即移行 | 0.25 人日 | デプロイ + 動作確認のみ |
| 🟡 PG-native + アプリ側調整 | 1.0 人日 | デプロイ + アプリ改修 + 結合テスト |
| 🔴 失敗・人手対応 | 3.0 人日〜 | 内容次第で大きく変動 (CLR は別途設計) |

> ⚠️ **これは簡易な目安**です。実際は依存テーブル数・アプリ側影響範囲・テストカバレッジ要求で大きく変わります。お客様環境での実績は §6.2 の SUMMARY.md を参照しつつ、ヒアリング (§8) の結果を踏まえて見積もりしてください。

### 6.4 NG (失敗) オブジェクトの扱い

`result/<obj>/NG.txt` に「なぜ失敗したか」が記載されます。典型的な NG パターン:

| NG 理由 | 推奨対応 |
|---|---|
| `WITH ENCRYPTION` で definition 取得不可 | お客様から平文 T-SQL を提供してもらう |
| CLR ストアド | 再実装 (Lambda / 純粋 PG 関数) |
| リンクサーバ参照 | FDW (postgres_fdw / tds_fdw) で再設計 |
| 想定外 T-SQL 構文 / システム関数 | 手動で PL/pgSQL に書き換え |
| テスト結果が大きく乖離 | ロジック差異を人手で精査 |

---

## 7. スコープ外と次ステップ

### 7.1 このツールのスコープ外

このツールは **「ソースコード (DB オブジェクト) の自動変換と検証」**だけを担います。実プロジェクトでは以下が別途必要です:

| 作業 | 推奨ツール / アプローチ |
|---|---|
| テーブル / インデックス / 制約の DDL 変換 | AWS Schema Conversion Tool (SCT) |
| データ移行 | AWS Database Migration Service (DMS) |
| アプリケーション側の接続文字列 / ドライバ修正 | お客様アプリチーム |
| パフォーマンステスト | pgbench / カスタムテスト |
| 本番カットオーバー手順 | 別途プロジェクト計画 |
| バックアップ / DR 設計 | Aurora 自動バックアップ + Cross-Region Snapshot |

### 7.2 推奨次ステップ (本ツールの結果を受けて)

```
1. Babelfish 即移行リストの確定 (🟢 件数 × 1次レビュー)
2. PG-native 移行リストの確定 (🟡 件数 × アプリ側影響評価)
3. NG オブジェクトの個別計画 (🔴 件数 × 工数積算)
4. テーブル / データ移行計画の策定 (SCT + DMS)
5. アプリ側ドライバ移行計画
6. 統合テスト計画 (本ツールが生成したテストを再利用可能)
7. 本番カットオーバー計画
```

---

## 8. ヒアリングシート (キックオフで使用)

お客様との初回打ち合わせ時にコピペで使えます。

```
============================================================
MSSQL → Aurora PG / Babelfish 移行アセスメント ヒアリングシート
============================================================

【0. 概要】
  お客様プロジェクト名:  ___________________
  キックオフ日:            ___________________
  目標完了日:              ___________________
  検証成功の定義:          (例) 全 procedure の 80% 以上が自動変換

【1. AWS 環境】
  □ 検証用アカウントの提供形態:
       [ ] A. お客様提供 PoC アカウント (弊社 IAM に AdministratorAccess 付与)
       [ ] B. 弊社提供アカウント (お客様から Snapshot を共有・コピー)
  □ 検証用 AWS アカウント ID:           ___________________
  □ 弊社作業者の IAM 権限:               [ ] 付与済 [ ] 着手前
  □ リージョン (us-east-1 必須):          [ ] OK  [ ] 要相談
  □ Bedrock Claude Sonnet 4.5 アクセス:    [ ] 取得済 [ ] 申請中 [ ] 未着手
  □ 既存 VPC / 既存 RDS との相互接続:     [ ] 不要 [ ] 必要 (詳細: _______ )

【2. ソース DB】
  □ SQL Server バージョン / Edition:    ____ / ____ (例: 2019 Standard)
  □ 元インスタンスクラス:                  ___________________ (例: db.m5.xlarge)
  □ DB サイズ (GB):                       ___________________
  □ Snapshot のクロスアカウントコピー (§4.5):
       [ ] 既に検証用アカウントへコピー済
       [ ] これから実施予定 (弊社からの手順書を確認)
       [ ] サンプルモードでデモのみ (Snapshot 不要)
  □ 本番アカウント ID:                    ___________________
  □ 本番リージョン:                       ___________________
  □ Snapshot ARN (検証用アカウントにコピー済のもの):
       ___________________________________________________
  □ Snapshot 暗号化:                      [ ] なし [ ] あり (KMS: _______ )
  □ KMS キーの種類:                       [ ] AWS managed (再暗号化要) [ ] CMK (共有可)
  □ 抽出対象データベース名:                ___________________ (例: YourAppDb)

【3. 対象オブジェクト】
  ※ オブジェクト名のリストアップは不要です。
     Snapshot 復元後に弊側で sys.objects から自動抽出します。

  □ 対象スキーマ (例: dbo, app):           ___________________
  □ 全件処理を希望 / 上位N件のみ:           [ ] 全件 [ ] 上位 ___ 件
  □ 優先度高のオブジェクト (任意):          別紙 or 自動抽出後に協議

【4. 自動変換 NG 候補の有無】
  □ WITH ENCRYPTION で保護された procedure: [ ] 0 件 [ ] あり (___件)
  □ CLR ストアド (.NET):                  [ ] 0 件 [ ] あり (___件)
  □ リンクサーバ / OPENQUERY:              [ ] 不使用 [ ] 使用 (___件)
  □ SQL Server Agent ジョブ:               [ ] 不使用 [ ] 使用 (___件)
  □ SSIS / Service Broker / DBMail:        [ ] 不使用 [ ] 使用 (詳細: _______ )

【5. アプリ側】
  □ 利用ドライバ (例: SqlClient / ODBC / JDBC): _______________
  □ Babelfish (TDS:1433 維持) で行きたい意向: [ ] 強い [ ] 中立 [ ] 弱い
  □ ネイティブ PG への切替許容度:          [ ] 全面OK [ ] 一部のみ [ ] 不可

【6. アプリ実行クエリ取得 (任意)】
  □ Query Store の有効化状況:              [ ] 有効 [ ] 無効 [ ] 不明
       確認 SQL:
         SELECT name, is_query_store_on FROM sys.databases WHERE name='YourAppDb';
  □ Query Store の保持期間 (有効な場合):    約 ___ 日

【7. テスト】
  □ 既存テストデータ提供可:                [ ] あり [ ] なし
  □ 期待出力 / 黄金値の提供可:             [ ] あり [ ] なし
  □ AI 自動生成テストの許容:                [ ] OK   [ ] 要レビュー

【8. ゴール / 合意事項】
  □ 成功の定義 (% / 件数):                 ___________________
  □ 検証期間 / 工数:                       ___________________
  □ 報告フォーマット:                      [ ] SUMMARY.md [ ] スライド [ ] 別紙
  □ 次フェーズ (DDL/DML 移行) の計画:      [ ] 別途 [ ] 本フェーズ内
============================================================
```

---

## 9. FAQ

### Q1. 本番 DB を直接読みに行きませんか?
**A.** 行きません。Snapshot から作成したクローン RDS のみ操作します。

### Q2. お客様データが Bedrock に学習されませんか?
**A.** Bedrock の API 呼び出しはお客様データの学習に利用されません ([Bedrock のデータプライバシ](https://aws.amazon.com/jp/bedrock/security-compliance/) 参照)。リージョンも `us-east-1` で完結します。

### Q3. コストはどれくらい?
**A.** 検証期間中の概算 (us-east-1 / 24時間稼働):
- Aurora PG (Serverless v2 0.5ACU): ~$3/日
- Aurora PG with Babelfish (db.r6i.large): ~$8/日
- RDS SQL Server: 元 Snapshot のサイズ依存 (db.m5.xlarge で ~$15/日)
- Workbench EC2 (t3.medium): ~$1/日
- Bedrock Claude Sonnet 4.5: 使用量次第 (21 オブジェクト変換で ~$10〜30 が目安)

→ **検証期間 1 週間で ~$200〜500** が目安。終了後は必ず `destroy.sh` で停止。

### Q4. どれくらいの精度?
**A.** サンプル 21 オブジェクト ([SUMMARY](./run-results/2026-05-24/SUMMARY.md)) で **95% (20/21) が自動変換成功**。ただしお客様の T-SQL の癖 (動的 SQL の多用、外部依存等) で大きく変動します。

### Q5. 何件まで一度に処理できますか?
**A.** 現実的な上限は 1 回あたり **~50 件**。それ以上は object_list を分割して複数回実行を推奨。Bedrock RPM 上限緩和申請が前提です。

### Q6. 変換結果が実は間違っていることはありませんか?
**A.** ありえます。本ツールは「**MSSQL での実行結果と Babelfish/PG での実行結果を比較**」しているので構文の通過 + 結果一致まで担保しますが:
- AI が生成したテストケースが網羅できていない可能性
- 副作用 (トランザクション境界・ロック挙動) は検証範囲外
- 大量データでの挙動 (PIVOT / 再帰 CTE 等) は別途負荷テスト必須

→ **本番投入前のお客様レビューと結合テストは必須**です。

### Q7. お客様が結果をレビューする際、何を見れば良い?
**A.** 各 `result/<obj>/` ディレクトリ内の以下:
- `mssql.sql` (元 T-SQL)
- `BABELFISH_OK.txt` または `OK.txt` (検証結果)
- `postgres.sql` (PG ネイティブ変換結果、🟡 のみ)
- `babelfish_test.txt` / `postgres_test.txt` (実行ログ)
- `comparison_result.txt` (差分判定の根拠)

総括は `SUMMARY.md` を見れば全体像がわかります。

### Q8. 失敗した場合、どこに連絡すれば?
**A.** プロジェクト担当 SA / AM へ。`result/<obj>/NG.txt` と `run-logs/run-*.failed` を共有してもらえれば調査可能です。

---

## 10. 関連ドキュメント

| 用途 | ドキュメント |
|---|---|
| 全体アーキ | [01-architecture.md](./01-architecture.md) |
| 詳細実行手順 (技術コマンド) | [02-runbook.md](./02-runbook.md) |
| Snapshot からのオブジェクト抽出 | [03-source-extraction.md](./03-source-extraction.md) |
| Babelfish vs PG-native の判定基準 | [04-conversion-strategy.md](./04-conversion-strategy.md) |
| テスト戦略 / 結果比較ロジック | [05-test-strategy.md](./05-test-strategy.md) |
| 直近の検証結果サマリ | [run-results/2026-05-24/SUMMARY.md](./run-results/2026-05-24/SUMMARY.md) |
| アーキテクチャ決定記録 | [adr/](./adr/) |
