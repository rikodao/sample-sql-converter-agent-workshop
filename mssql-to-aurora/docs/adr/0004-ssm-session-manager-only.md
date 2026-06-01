# ADR-0004: Workbench EC2 への接続は SSM Session Manager 一本にする

- ステータス: Accepted
- 日付: 2026-05-23

## コンテキスト

Workbench EC2 (Strands Agents の実行ホスト) への接続方式として複数の選択肢がある:

1. SSH (公開鍵 + Security Group で IP 制限)
2. SSH (公開鍵 + EC2 Instance Connect Endpoint 経由)
3. SSM Session Manager (SSH 不要)

## 検討した選択肢

### A. SSH + 0.0.0.0/0 SG
- ❌ 採用不可 (パブリックインターネット全開放)

### B. SSH + 自宅IP / 社内IP に制限
- Pros: SSH クライアントそのまま使える
- Cons: IP 変動時にメンテ必要、Bastion要らないがSGに人手が入る、監査ログがCloudTrailに乗らない
- 評価: 🟡 セキュリティ的には許容範囲だがメンテ負荷あり

### C. SSH + EC2 Instance Connect Endpoint
- Pros: パブリック IP 不要、IAM 認証、CloudTrail 監査可能
- Cons: IC Endpoint リソース追加、SG に 22/tcp ルールが残る (sgIce からのみだが)
- 評価: ✅ セキュア。ただし運用上 SG ルールは「無いのが一番安全」

### D. SSM Session Manager のみ ⭐ 採用
- Pros:
  - SSH ポート (22) を一切開放しない (SG レベルで遮断)
  - Key Pair 管理不要
  - IAM 認証 + CloudTrail 監査 + S3/CloudWatch にセッションログ保存可能
  - ポートフォワード機能あり (`AWS-StartPortForwardingSessionToRemoteHost`) で DB への一時的な接続も可能
  - IC Endpoint リソースが不要 (シンプル化)
- Cons:
  - ローカル端末に Session Manager Plugin の導入必要
  - SSH の慣性 (scp, sftp 等) が使えない (S3 経由で代替)
- 評価: ✅ ✅ 採用

## 決定

**選択肢 D を採用**: 

- Workbench EC2 の SG はインバウンド完全クローズ (allowAllOutbound のみ)
- Key Pair は作成しない (`CfnKeyPair` なし)
- EC2 Instance Connect Endpoint は作成しない
- 接続は `aws ssm start-session --target <instance-id>` 一本
- ファイル転送・結果取り出しは S3 経由
- DB へのローカル接続が必要な場合はポートフォワード:
  ```
  aws ssm start-session --target <id> \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters '{"host":["<db-endpoint>"],"portNumber":["5432"],"localPortNumber":["15432"]}'
  ```

## 影響

- `cdk/lib/constructs/network.ts`: IC Endpoint と sgIce を削除
- `cdk/lib/constructs/workbench-ec2.ts`: KeyPair / SG ingress 22 を削除
- `scripts/deploy.sh`: Key Pair 取得処理と ssh-config 生成を削除、SSM コマンド出力に変更
- `scripts/destroy.sh`: pem ファイル / ssh-config の削除パスは維持 (古い実行物クリーンアップ用)
- `docs/01-architecture.md`, `02-runbook.md`, `README.md`: SSM接続手順に書き換え

## 前提条件 (利用者側)

- ローカル端末に AWS CLI v2 と [Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) のインストール
- IAM ユーザー / ロールに `ssm:StartSession` 権限
