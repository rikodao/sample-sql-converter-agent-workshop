import { Duration, RemovalPolicy } from 'aws-cdk-lib';
import {
  InstanceClass,
  InstanceSize,
  InstanceType,
  SecurityGroup,
  SubnetType,
  Vpc,
} from 'aws-cdk-lib/aws-ec2';
import {
  AuroraPostgresEngineVersion,
  ClusterInstance,
  Credentials,
  DatabaseCluster,
  DatabaseClusterEngine,
  ParameterGroup,
} from 'aws-cdk-lib/aws-rds';
import { Secret } from 'aws-cdk-lib/aws-secretsmanager';
import { Construct } from 'constructs';

export interface TargetBabelfishProps {
  vpc: Vpc;
}

/**
 * Target #2: Aurora PostgreSQL with Babelfish (T-SQL互換層, Provisioned)
 *
 * - Babelfish は 2026年5月時点で Aurora PostgreSQL 16.x に対応
 * - Serverless v2 にも対応するが ACU 下限・メモリ要件があるため
 *   検証では Provisioned db.r6i.large を採用（ADR-0001 参照）
 * - PG接続(5432) と TDS接続(1433) の両方が可能
 *
 * Cluster Parameter Group のキー設定:
 *   rds.babelfish_status = on
 *   babelfishpg_tsql.migration_mode = single-db (or multi-db)
 *   babelfishpg_tds.tds_default_numeric_precision = 38
 */
export class TargetBabelfish extends Construct {
  readonly cluster: DatabaseCluster;
  readonly credentials: Secret;
  readonly securityGroup: SecurityGroup;

  constructor(scope: Construct, id: string, props: TargetBabelfishProps) {
    super(scope, id);

    this.credentials = new Secret(this, 'Credentials', {
      secretName: 'mssql-to-aurora/target-babelfish-credentials',
      generateSecretString: {
        secretStringTemplate: JSON.stringify({ username: 'babelfish_user' }),
        excludePunctuation: true,
        includeSpace: false,
        generateStringKey: 'password',
        passwordLength: 24,
      },
      removalPolicy: RemovalPolicy.DESTROY,
    });

    this.securityGroup = new SecurityGroup(this, 'Sg', {
      vpc: props.vpc,
      description: 'Target Aurora PostgreSQL with Babelfish (PG:5432, TDS:1433)',
      allowAllOutbound: true,
    });

    // Babelfish 用 Cluster Parameter Group
    // 注: defaultDatabaseName は使わない (Babelfish が migration_mode=single-db のとき
    //     自動で 'babelfish_db' という T-SQL DB を作成する。事前に同名の通常DBがあると
    //     Babelfish 初期化が失敗する)。
    const engine = DatabaseClusterEngine.auroraPostgres({
      version: AuroraPostgresEngineVersion.VER_16_4,
    });

    const clusterParamGroup = new ParameterGroup(this, 'ClusterParamGroupV2', {
      engine,
      description: 'Babelfish enabled cluster parameter group v2',
      parameters: {
        'rds.babelfish_status': 'on',
        'babelfishpg_tsql.migration_mode': 'single-db',
      },
    });

    this.cluster = new DatabaseCluster(this, 'Cluster', {
      engine,
      credentials: Credentials.fromSecret(this.credentials),
      vpc: props.vpc,
      vpcSubnets: { subnetType: SubnetType.PRIVATE_ISOLATED },
      securityGroups: [this.securityGroup],
      writer: ClusterInstance.provisioned('writer', {
        instanceType: InstanceType.of(InstanceClass.R6I, InstanceSize.LARGE),
      }),
      parameterGroup: clusterParamGroup,
      // defaultDatabaseName は指定しない (Babelfish が初期化時に作成する)
      storageEncrypted: true,
      deletionProtection: false,
      iamAuthentication: true,
      backup: { retention: Duration.days(1) },
      removalPolicy: RemovalPolicy.DESTROY,
    });
  }
}
