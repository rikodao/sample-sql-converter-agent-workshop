# SCT Host — Ubuntu + SQL Server 2022 Developer Edition (Ansible)

`AWS Schema Conversion Tool (SCT)` で RDS for SQL Server をソースにできない問題への対処として、
**Ubuntu EC2 + SQL Server 2022 Developer Edition (on Linux)** を Ansible で IaC 化したもの。

詳細手順: [docs/HOWTO.md](./docs/HOWTO.md)

## 用途

```
お客様の本番 RDS for SQL Server
   ↓ (DBA 作業) native backup → S3 へ .bak エクスポート
S3 (検証用アカウント)
   ↓ 本ツール (Ansible)
Ubuntu EC2 + SQL Server Developer Edition
   ↓ SCT / DMS Schema Conversion で接続
テーブル DDL 変換結果
```

## ライセンス

- **SQL Server Developer Edition** は Microsoft が **無償提供** (評価・開発・テスト・デモ目的)
- AWS Marketplace 不要、Microsoft 公式 apt repo から直接インストール
- 移行評価作業は Microsoft EULA 上 "evaluation" / "test" の範疇
- 本番運用は不可、評価終了後は速やかに削除

## ディレクトリ構成

```
extraction/sct-host/
├── README.md                                 (本ファイル)
├── ansible/
│   ├── ansible.cfg
│   ├── inventory.ini.template                (SSH / SSM / localhost の3例)
│   ├── playbook.yml
│   ├── group_vars/all.yml.template
│   └── roles/sql_server/
│       ├── defaults/main.yml
│       ├── handlers/main.yml
│       └── tasks/
│           ├── main.yml                      (オーケストレータ)
│           ├── prereq.yml                    (apt update + AWS CLI)
│           ├── install.yml                   (Microsoft repo + mssql-server)
│           ├── configure.yml                 (mssql-conf + 起動)
│           ├── firewall.yml                  (ufw 1433/tcp)
│           └── restore.yml                   (S3 → bak → DB 復元)
├── scripts/
│   ├── bootstrap.sh                          (EC2 上で self-bootstrap 一発)
│   └── run-ansible.sh                        (リモートから流すヘルパー)
└── docs/
    └── HOWTO.md                              (詳細手順)
```

## 最短実行 (self-bootstrap)

Ubuntu 22.04 EC2 にログインして:

```bash
sudo MSSQL_SA_PASSWORD='YourStrongP@ss2026' \
     bash extraction/sct-host/scripts/bootstrap.sh
```

5〜10 分で `127.0.0.1:1433` で SQL Server が応答する状態になる。

## 想定環境

| 項目 | 推奨 |
|---|---|
| OS | Ubuntu 22.04 LTS / 24.04 LTS |
| EC2 タイプ | m5.xlarge 以上 (4 vCPU / 16 GB RAM) |
| EBS | 100 GB+ (DB サイズに応じて) gp3 推奨 |
| ネットワーク | Private Subnet + SG 1433 を SCT 接続元から許可 |
| IAM Role | S3 GetObject (bak ダウンロード用) |
| 接続方式 | SSM Session Manager 推奨 (SSH 不要) |

## コスト目安

| 構成 | 1 週間 |
|---|---|
| Ubuntu EC2 m5.xlarge + 100GB gp3 | $32 + $8 = **$40** |
| (参考) Windows LI AMI 同等 | $84 + $8 = $92 |

→ Linux + Developer Edition で **約 半額**。
