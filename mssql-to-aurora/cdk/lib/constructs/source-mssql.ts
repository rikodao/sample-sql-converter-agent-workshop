import { Duration, RemovalPolicy } from 'aws-cdk-lib';
import {
  InstanceType,
  SecurityGroup,
  SubnetType,
  Vpc,
} from 'aws-cdk-lib/aws-ec2';
import {
  Credentials,
  DatabaseInstance,
  DatabaseInstanceFromSnapshot,
  IDatabaseInstance,
  LicenseModel,
  SnapshotCredentials,
  SqlServerEngineVersion,
  StorageType,
  DatabaseInstanceEngine,
} from 'aws-cdk-lib/aws-rds';
import { BlockPublicAccess, Bucket, BucketEncryption } from 'aws-cdk-lib/aws-s3';
import { BucketDeployment, Source as S3Source } from 'aws-cdk-lib/aws-s3-deployment';
import { Secret } from 'aws-cdk-lib/aws-secretsmanager';
import { Construct } from 'constructs';
import * as path from 'path';

export interface SourceMssqlProps {
  vpc: Vpc;
  /**
   * 'sample': 空のRDSを作成し、deploy.shで sample_objects.sql を流し込む
   * 'snapshot': 指定したsnapshotIdentifierから復元する
   */
  sourceMode: 'sample' | 'snapshot';
  snapshotIdentifier?: string;
  /** 例: db.t3.small / db.m5.xlarge */
  instanceClass?: string;
}

/**
 * 検証用 RDS for SQL Server。
 * sample モード: db.t3.small Express Edition の空DB
 * snapshot モード: 指定スナップショットから復元（実RDSの本番互換）
 */
export class SourceMssql extends Construct {
  readonly instance: IDatabaseInstance;
  readonly credentials: Secret;
  readonly securityGroup: SecurityGroup;
  readonly extractionBucket: Bucket;

  constructor(scope: Construct, id: string, props: SourceMssqlProps) {
    super(scope, id);

    // クレデンシャル
    this.credentials = new Secret(this, 'Credentials', {
      secretName: 'mssql-to-aurora/source-mssql-credentials',
      generateSecretString: {
        secretStringTemplate: JSON.stringify({ username: 'mssqladmin' }),
        excludePunctuation: true,
        includeSpace: false,
        generateStringKey: 'password',
        passwordLength: 24,
      },
      removalPolicy: RemovalPolicy.DESTROY,
    });

    // SG
    this.securityGroup = new SecurityGroup(this, 'Sg', {
      vpc: props.vpc,
      description: 'Source RDS for SQL Server',
      allowAllOutbound: true,
    });

    // S3 (DDL抽出 / サンプル投入の置き場)
    this.extractionBucket = new Bucket(this, 'ExtractionBucket', {
      blockPublicAccess: BlockPublicAccess.BLOCK_ALL,
      encryption: BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      removalPolicy: RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      serverAccessLogsPrefix: 'AccessLogs/',
    });

    // テストDDLをBucketにデプロイ（sampleモードのみ。snapshotモードでも置いておくのは無害）
    new BucketDeployment(this, 'DeployTests', {
      sources: [S3Source.asset(path.join(__dirname, '..', '..', '..', 'tests'))],
      destinationBucket: this.extractionBucket,
      destinationKeyPrefix: 'tests/',
    });

    // インスタンスクラス決定 (例: 'db.t3.small' → 't3.small')
    const ic = props.instanceClass ?? 'db.t3.small';
    const instanceType = new InstanceType(
      ic.startsWith('db.') ? ic.substring(3) : ic
    );

    // sourceMode による分岐
    if (props.sourceMode === 'snapshot') {
      if (!props.snapshotIdentifier) {
        throw new Error('snapshotIdentifier is required when sourceMode=snapshot');
      }
      this.instance = new DatabaseInstanceFromSnapshot(this, 'Instance', {
        snapshotIdentifier: props.snapshotIdentifier,
        engine: DatabaseInstanceEngine.sqlServerEx({
          version: SqlServerEngineVersion.VER_16,
        }),
        instanceType,
        vpc: props.vpc,
        vpcSubnets: { subnetType: SubnetType.PRIVATE_ISOLATED },
        securityGroups: [this.securityGroup],
        // Snapshot から復元する場合は SnapshotCredentials が必要
        credentials: SnapshotCredentials.fromSecret(this.credentials),
        // storageEncrypted は Snapshot 元の設定を引き継ぐため指定不可
        backupRetention: Duration.days(1),
        deletionProtection: false,
        removalPolicy: RemovalPolicy.DESTROY,
        publiclyAccessible: false,
        licenseModel: LicenseModel.LICENSE_INCLUDED,
      });
    } else {
      this.instance = new DatabaseInstance(this, 'Instance', {
        engine: DatabaseInstanceEngine.sqlServerEx({
          version: SqlServerEngineVersion.VER_16,
        }),
        instanceType,
        vpc: props.vpc,
        vpcSubnets: { subnetType: SubnetType.PRIVATE_ISOLATED },
        securityGroups: [this.securityGroup],
        credentials: Credentials.fromSecret(this.credentials),
        allocatedStorage: 50,
        storageType: StorageType.GP3,
        storageEncrypted: true,
        backupRetention: Duration.days(1),
        deletionProtection: false,
        removalPolicy: RemovalPolicy.DESTROY,
        publiclyAccessible: false,
        licenseModel: LicenseModel.LICENSE_INCLUDED,
      });
    }

    // SGの 1433 開放は workbench-ec2 側から allowFrom で行う
  }
}
