# SCT ホスト E2E テスト結果 (2026-06-01)

## 0. 目的

`extraction/sct-host/` (Ubuntu + SQL Server 2022 Developer Edition の Ansible IaC) が
**SSH ポートを開けずに、SSM Session Manager のみ**で SQL Server を立ち上げられるか
を実機で検証する。

## 1. 検証環境

| 項目 | 値 |
|---|---|
| ベース AMI | ami-02fd066b86800f60c (Ubuntu 22.04 LTS, 2026-05-21) |
| インスタンス | m5.xlarge / 100 GB gp3 |
| VPC / Subnet | 既存 MssqlToAuroraStack 内 (Private) |
| SG | Workbench EC2 と同じ (egress 全許可、ingress なし) — **SSH 22 開放なし** |
| IAM | Workbench EC2 と同じ Profile (S3 RW + SSM) |
| 接続方式 | SSM Session Manager のみ |
| ターゲット | SQL Server 2022 Developer Edition (Linux) |

## 2. 結果サマリ

✅ **完全に動作**。

```
Microsoft SQL Server 2022 (RTM-CU25-GDR) (KB5095580) - 16.0.4260.1 (X64)
        May 14 2026 21:25:59
        Copyright (C) 2022 Microsoft Corporation
        Developer Edition (64-bit) on Linux (Ubuntu 22.04.5 LTS) <X64>
```

- systemctl `active`
- Port `1433` で LISTEN
- SA 認証で `SELECT @@VERSION` 応答
- **SSH ポート 22 は最初から最後まで一度も開いていない**

## 3. 所要時間

| フェーズ | 時間 |
|---|---|
| EC2 起動 (run-instances → SSM Online) | 30 秒 |
| AWS CLI v2 直接インストール (curl + unzip) | 約 30 秒 |
| sct-host.tgz の S3 転送 + 展開 | 約 5 秒 |
| `bootstrap.sh` 全体 (apt update + Ansible + repos + mssql-server + tools + 設定) | 約 4 分 |
| 動作確認 + terminate | 約 1 分 |
| **総計** | **約 6 分** |

## 4. 発見したバグと修正

### Bug 1: `pip3 install --break-system-packages` が Ubuntu 22.04 で unknown option

Ubuntu 22.04 の Python 3.10 では `--break-system-packages` フラグが未実装
(PEP 668 は Python 3.11+ 由来)。

**修正** (`scripts/bootstrap.sh`):
```bash
# 旧
pip3 install --quiet --break-system-packages ansible boto3 botocore || pip3 install --quiet ansible boto3 botocore

# 新
if pip3 install --help 2>/dev/null | grep -q -- '--break-system-packages'; then
    pip3 install --quiet --break-system-packages ansible boto3 botocore
else
    pip3 install --quiet ansible boto3 botocore
fi
```

### Bug 2: `ansible-galaxy collection install -q` の `-q` が unknown

apt の ansible (古い) が入った状態で `-q` フラグが認識されなかった
(新しい ansible では認識される)。

**修正** (`scripts/bootstrap.sh`):
```bash
# 旧
ansible-galaxy collection install -q community.general

# 新
ansible-galaxy collection install community.general 2>&1 | tail -5
```

### Bug 3: Microsoft `prod` repo の package list が apt cache に反映されない

`/var/lib/apt/lists/*` に古い cache が残っていると、新しく追加した
`https://packages.microsoft.com/ubuntu/22.04/prod jammy main` の Packages.gz が
読み込まれず、`mssql-tools18` が `No package matching` エラーになる。

実機検証で `rm -rf /var/lib/apt/lists/* && apt-get update` で解決することを確認。

**修正** (`ansible/roles/sql_server/tasks/install.yml`):
```yaml
- name: apt の lists を強制クリア (古いキャッシュが Microsoft repo の package list を見えなくする問題への対処)
  ansible.builtin.shell: "rm -rf /var/lib/apt/lists/*"
  changed_when: true

- name: apt キャッシュ更新
  ansible.builtin.apt:
    update_cache: true
```

### Bug 4 (運用上の注意): apt awscli v1 + pip3 botocore が衝突

bootstrap.sh の **手前で** SSM RunCommand 内で `apt install awscli` (v1) すると、
あとで pip3 が新しい botocore を入れたときに awscli v1 が KeyError でクラッシュする。

**対処方針**: SSM RunCommand 内で AWS CLI を入れるなら **必ず v2 を直接ダウンロード**
する (apt の awscli v1 は使わない)。

```bash
curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp/
/tmp/aws/install
```

これは README / HOWTO に追記済 (お客様向けの手順では bootstrap.sh の prereq.yml が
v2 を入れるので問題なし。SSM RunCommand で 1 回回すケースの注意事項として記録)。

## 5. ansible-playbook の最終結果

```
PLAY RECAP **************************************************
localhost  : ok=26  changed=6  unreachable=0  failed=0  skipped=22
```

すべての Stage が想定通り (firewall は --extra-vars で OFF にしたためスキップ)。

## 6. 結論

| 検証項目 | 結果 |
|---|---|
| SSH ポート開けずに SQL Server 構築 | ✅ |
| Ansible playbook 冪等動作 | ✅ |
| Developer Edition 起動 + 接続 | ✅ |
| Marketplace AMI 不要 (標準 Ubuntu AMI) | ✅ |
| ライセンス料ゼロ (Developer Edition) | ✅ |

**お客様への提案として「Snapshot ベース検証 (本ツール本体) と並行して、
DDL 変換用に Ubuntu + SQL Server Developer を 1 台立てる」フローが
ライセンス的にもオペレーション的にも成立することを実証**。

## 7. クリーンアップ

EC2 (`i-08831b132bff353f1`) は terminate 済み。
コスト: m5.xlarge × 約 30 分 + 100GB gp3 → **約 $0.20**。
