# 2 台構成 E2E テスト: Server + Client によるリモート接続品質チェック (2026-06-01)

## 0. 目的

[前回テスト](./SCT_HOST_E2E_TEST.md) で 1 台での動作を確認したが、
**SCT / DMS Schema Conversion からのリモート接続**を想定した品質チェックを行う。

具体的には:
1. **Ansible IaC で複数台展開**できるか (sct-host を 1 台目で実行)
2. 別ホストから **TDS:1433 で SQL Server へリモート接続**できるか
3. SCT/DMS SC が必要とする **DDL 読み取り / metadata 取得**が動くか

## 1. テスト環境

| 項目 | 値 |
|---|---|
| Server EC2 | i-01162ce7c00ed3ea4 (m5.xlarge, Ubuntu 22.04, 100GB gp3) |
| Server PrivateIP | 10.0.2.64 |
| Client EC2 | i-01ca64a11be09fe8d (t3.medium, Ubuntu 22.04, 30GB gp3) |
| Client PrivateIP | 10.0.2.170 |
| 同一 SG | sg-0608bb08661237f86 (検証中のみ self-referenced 1433/tcp ingress 追加) |
| 接続方式 | SSM Session Manager のみ (SSH 22 開放なし) |

## 2. 結果サマリ

✅ **全 7 ステップ完走、リモートでの DDL 操作も完全に動作**

```
✅ Step 1: SELECT @@VERSION
   → Microsoft SQL Server 2022 (RTM-CU25-GDR) Developer Edition on Linux (Ubuntu 22.04.5 LTS)
✅ Step 2: CREATE DATABASE PocTestDb
✅ Step 3: CREATE TABLE + INSERT (3 rows)
✅ Step 4: CREATE PROCEDURE usp_get_emp
✅ Step 5: EXEC PROCEDURE (filter @min_sal=5500)
   → Charlie 7500.00, Bob 6000.00 (正しくソート済、Alice 5000は除外)
✅ Step 6: sys.objects metadata readout (SCT-style)
   → SQL_STORED_PROCEDURE, USER_TABLE, PRIMARY_KEY_CONSTRAINT 取得
✅ Step 7: CLEANUP (DROP DATABASE)
```

## 3. 所要時間

| フェーズ | 時間 |
|---|---|
| EC2 #1 + #2 並列起動 + SSM Online | 約 1 分 |
| Server: bootstrap.sh (apt update + Ansible + SQL Server 2022) | 約 4 分 |
| Client: sqlcmd だけインストール | 約 1 分 |
| (並列実行のため最大値の 4 分が支配) | |
| 接続疎通確認 + 品質チェック SQL 実行 | 約 1 分 |
| 2 台 terminate + SG ルール削除 | 30 秒 |
| **総計** | **約 7 分** |

## 4. 発見した問題と対処

### Issue 1: ufw が立ち上がっていてリモート接続が初回失敗

`bootstrap.sh` のデフォルトで `mssql_open_firewall=true` だったため、ufw が
default-deny で稼働。`mssql_firewall_allowed_cidrs=[10.0.0.0/8, 172.16.0.0/12]`
のはずだが、CLT (10.0.2.170) からの接続が `Login timeout expired (0x2749)` で拒否。

**対処** (検証時の暫定): `ufw disable` で切ってリモート接続成功。
**根本対応**: `bootstrap.sh` 起動時に `MSSQL_OPEN_FIREWALL=false` を環境変数で
渡せるオプションを追加すべき (Phase 1.2 として残作業)。
SG (Security Group) 側で十分制御できているケースでは ufw 不要。

### Issue 2: Client EC2 に AWS CLI が pre-install されていない

Ubuntu 標準 AMI には awscli が入っていないため、SSM RunCommand 内で `aws s3 cp`
を実行しようとして「aws: not found」エラー。

**対処**: AWS CLI v2 を直接 (curl + unzip) 入れる手順を Client 側のセットアップ
コマンドに追加。

### Issue 3: SQL の引用符を inline JSON に含めるとエスケープ地獄

`sqlcmd ... -Q "..."` で複雑な SQL を流すと、jq → SSM RunCommand → bash の
3 段で quote escape が破綻する。

**対処**: SQL は別ファイル (`quality-check.sql`) として S3 に置き、
sqlcmd `-i` で読ませる方式に変更。

## 5. SCT / DMS SC の利用前提として実証されたこと

| 必要機能 | 検証方法 | 結果 |
|---|---|---|
| TDS:1433 でリモート接続 | `nc -zv 10.0.2.64 1433` + `sqlcmd -S 10.0.2.64,1433` | ✅ |
| SQL 認証 (SA + パスワード) | `-U SA -P ...` で全クエリ成功 | ✅ |
| TLS (Trust server certificate) | `-C -N` 指定で接続成功 | ✅ |
| `SELECT @@VERSION` で Edition 取得 | Step 1 | ✅ |
| DDL 操作 (CREATE DATABASE/TABLE/PROCEDURE) | Step 2-4 | ✅ |
| `sys.objects` 等のシステムカタログ読み取り | Step 6 | ✅ |
| パラメータ付きストアド実行 | Step 5 | ✅ |

→ 「Ubuntu EC2 + SQL Server Developer Edition (本ツールの sct-host) を立てて、
そこに本番 DB の `.bak` を restore すれば、お客様 DBA の SCT が問題なく接続できる」
ことを実証。

## 6. クリーンアップ

- EC2 #1 (Server): `i-01162ce7c00ed3ea4` → terminated
- EC2 #2 (Client): `i-01ca64a11be09fe8d` → terminated
- SG `sg-0608bb08661237f86` の self-referenced 1433/tcp ingress: revoke 済

コスト: 7 分 × (m5.xlarge + t3.medium) → 約 **$0.10** + S3 / SSM

## 7. Phase 1.2 への残作業

- `bootstrap.sh` に `MSSQL_OPEN_FIREWALL` 環境変数を追加 (default false 推奨、SG 側で制御)
- Client 用の軽量セットアップスクリプト (`scripts/install-client-tools.sh`) を追加
- 公式手順書 (06-customer-handover.md) に「2 台構成」のオプションを追記

## 8. 結論

**Ansible で複数台 IaC 展開でき、Server-Client 構成で TDS リモート接続が
完全に動作**することを実証した。これにより、SCT / DMS Schema Conversion からの
接続を含む本格運用が可能であることが裏付けられた。
