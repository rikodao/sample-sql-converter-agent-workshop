import { Duration, RemovalPolicy } from 'aws-cdk-lib';
import { SecurityGroup, SubnetType, Vpc } from 'aws-cdk-lib/aws-ec2';
import {
  AuroraPostgresEngineVersion,
  ClusterInstance,
  Credentials,
  DatabaseCluster,
  DatabaseClusterEngine,
} from 'aws-cdk-lib/aws-rds';
import { Secret } from 'aws-cdk-lib/aws-secretsmanager';
import { Construct } from 'constructs';

export interface TargetAuroraPgProps {
  vpc: Vpc;
}

/**
 * Target #1: Aurora PostgreSQL ネイティブ (Serverless v2, Data API有効)
 * 既存 Oracle 側の AuroraServerlessPg と同じ構成思想で実装し、
 * mcpserver/postgres.py（RDS Data API）を流用できるようにする。
 */
export class TargetAuroraPg extends Construct {
  readonly cluster: DatabaseCluster;
  readonly credentials: Secret;
  readonly securityGroup: SecurityGroup;

  constructor(scope: Construct, id: string, props: TargetAuroraPgProps) {
    super(scope, id);

    this.credentials = new Secret(this, 'Credentials', {
      secretName: 'mssql-to-aurora/target-pg-credentials',
      generateSecretString: {
        secretStringTemplate: JSON.stringify({ username: 'postgres' }),
        excludePunctuation: true,
        includeSpace: false,
        generateStringKey: 'password',
      },
      removalPolicy: RemovalPolicy.DESTROY,
    });

    this.securityGroup = new SecurityGroup(this, 'Sg', {
      vpc: props.vpc,
      description: 'Target Aurora PostgreSQL (native)',
      allowAllOutbound: true,
    });

    this.cluster = new DatabaseCluster(this, 'Cluster', {
      engine: DatabaseClusterEngine.auroraPostgres({
        version: AuroraPostgresEngineVersion.VER_15_10,
      }),
      credentials: Credentials.fromSecret(this.credentials),
      vpc: props.vpc,
      vpcSubnets: { subnetType: SubnetType.PRIVATE_ISOLATED },
      securityGroups: [this.securityGroup],
      serverlessV2MinCapacity: 0.5,
      serverlessV2MaxCapacity: 2,
      writer: ClusterInstance.serverlessV2('writer'),
      storageEncrypted: true,
      deletionProtection: false,
      iamAuthentication: true,
      backup: { retention: Duration.days(1) },
      enableDataApi: true,
      removalPolicy: RemovalPolicy.DESTROY,
    });
  }
}
