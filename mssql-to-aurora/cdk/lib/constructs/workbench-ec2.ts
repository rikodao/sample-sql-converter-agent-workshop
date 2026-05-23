import {
  BlockDeviceVolume,
  EbsDeviceVolumeType,
  Instance,
  InstanceClass,
  InstanceSize,
  InstanceType,
  MachineImage,
  Port,
  SecurityGroup,
  SubnetType,
  UserData,
  Vpc,
} from 'aws-cdk-lib/aws-ec2';
import {
  ManagedPolicy,
  PolicyStatement,
  Role,
  ServicePrincipal,
} from 'aws-cdk-lib/aws-iam';
import { Secret } from 'aws-cdk-lib/aws-secretsmanager';
import { Construct } from 'constructs';

export interface WorkbenchEc2Props {
  vpc: Vpc;
  sourceMssqlSg: SecurityGroup;
  targetPgSg: SecurityGroup;
  targetBabelfishSg: SecurityGroup;
  sourceMssqlSecret: Secret;
  targetPgSecret: Secret;
  targetBabelfishSecret: Secret;
  targetPgClusterArn: string;
  extractionBucketName: string;
}

/**
 * Workbench EC2: Strands Agents + MCP Server を実行する場所。
 *
 * 接続方式: SSM Session Manager のみ (SSH は無し)
 *   - 接続: aws ssm start-session --target <instance-id>
 *   - ポートフォワード: aws ssm start-session --target <instance-id> \
 *       --document-name AWS-StartPortForwardingSession --parameters '...'
 *
 * UserData で:
 *  - msodbcsql18 (MSSQL/Babelfish接続用)
 *  - unixODBC (TDS接続用)
 *  - uv, Python 3.12, git, jq
 * をインストールする。
 */
export class WorkbenchEc2 extends Construct {
  readonly instance: Instance;
  readonly instanceRole: Role;
  readonly securityGroup: SecurityGroup;

  constructor(scope: Construct, id: string, props: WorkbenchEc2Props) {
    super(scope, id);

    // SG (Workbench EC2 自身) - SSH 不可、Outbound のみ
    this.securityGroup = new SecurityGroup(this, 'Sg', {
      vpc: props.vpc,
      description: 'Workbench EC2 (SSM Session Manager only, no SSH inbound)',
      allowAllOutbound: true,
    });

    // 各DBへの接続許可 (workbench → DB)
    props.sourceMssqlSg.connections.allowFrom(this.securityGroup, Port.tcp(1433), 'MSSQL from workbench');
    props.targetPgSg.connections.allowFrom(this.securityGroup, Port.tcp(5432), 'PG from workbench');
    props.targetBabelfishSg.connections.allowFrom(this.securityGroup, Port.tcp(5432), 'Babelfish PG from workbench');
    props.targetBabelfishSg.connections.allowFrom(this.securityGroup, Port.tcp(1433), 'Babelfish TDS from workbench');

    // IAM Role (SSM Session Manager 必須権限を含む)
    this.instanceRole = new Role(this, 'Role', {
      assumedBy: new ServicePrincipal('ec2.amazonaws.com'),
      managedPolicies: [
        ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
        ManagedPolicy.fromAwsManagedPolicyName('AmazonBedrockFullAccess'),
      ],
    });
    props.sourceMssqlSecret.grantRead(this.instanceRole);
    props.targetPgSecret.grantRead(this.instanceRole);
    props.targetBabelfishSecret.grantRead(this.instanceRole);

    this.instanceRole.addToPolicy(
      new PolicyStatement({
        actions: [
          'rds-data:ExecuteStatement',
          'rds-data:BatchExecuteStatement',
          'rds-data:BeginTransaction',
          'rds-data:CommitTransaction',
          'rds-data:RollbackTransaction',
        ],
        resources: [props.targetPgClusterArn],
      })
    );
    this.instanceRole.addToPolicy(
      new PolicyStatement({
        actions: ['sts:GetCallerIdentity'],
        resources: ['*'],
      })
    );

    // UserData
    const userData = UserData.forLinux();
    userData.addCommands(
      '#!/bin/bash',
      'set -eux',
      'dnf update -y',
      'dnf install -y git tar gzip make gcc python3.12 python3.12-devel unixODBC unixODBC-devel jq',
      // Microsoft GPG key + ODBC Driver 18 for SQL Server (RHEL 9 repo works on AL2023)
      'rpm --import https://packages.microsoft.com/keys/microsoft.asc',
      'curl -sSL https://packages.microsoft.com/config/rhel/9/prod.repo > /etc/yum.repos.d/mssql-release.repo',
      'ACCEPT_EULA=Y dnf install -y msodbcsql18 mssql-tools18',
      'echo \'export PATH="$PATH:/opt/mssql-tools18/bin"\' > /etc/profile.d/mssql-tools.sh',
      // uv (system-wide)
      'curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh',
      // ec2-user PATH
      'echo \'export PATH="$HOME/.local/bin:/opt/mssql-tools18/bin:$PATH"\' >> /home/ec2-user/.bashrc',
      'chown -R ec2-user:ec2-user /home/ec2-user',
      // 完了マーカー (deploy.sh から状態確認に使う)
      'touch /var/log/userdata-complete'
    );

    // EC2 (キーペア無し、SSH 接続不可)
    this.instance = new Instance(this, 'Instance', {
      vpc: props.vpc,
      vpcSubnets: { subnetType: SubnetType.PRIVATE_WITH_EGRESS },
      instanceType: InstanceType.of(InstanceClass.T3, InstanceSize.MEDIUM),
      machineImage: MachineImage.lookup({
        name: 'al2023-ami-2023.*-kernel-6.1-x86_64',
        owners: ['amazon'],
      }),
      securityGroup: this.securityGroup,
      role: this.instanceRole,
      userData,
      detailedMonitoring: true,
      blockDevices: [
        {
          deviceName: '/dev/xvda',
          volume: BlockDeviceVolume.ebs(50, {
            volumeType: EbsDeviceVolumeType.GP3,
            deleteOnTermination: true,
            encrypted: true,
          }),
        },
      ],
    });
  }
}
