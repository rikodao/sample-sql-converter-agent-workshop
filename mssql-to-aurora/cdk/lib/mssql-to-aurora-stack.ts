import { CfnOutput, Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { Network } from './constructs/network';
import { SourceMssql } from './constructs/source-mssql';
import { TargetAuroraPg } from './constructs/target-aurora-pg';
import { TargetBabelfish } from './constructs/target-babelfish';
import { WorkbenchEc2 } from './constructs/workbench-ec2';

export class MssqlToAuroraStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    // CDK context で sourceMode を切替（sample / snapshot）
    const sourceMode = (this.node.tryGetContext('sourceMode') as string) ?? 'sample';
    const snapshotIdentifier = this.node.tryGetContext('snapshotIdentifier') as
      | string
      | undefined;
    const sourceInstanceClass = this.node.tryGetContext('sourceInstanceClass') as
      | string
      | undefined;

    // 1. Network (VPC, IC Endpoint)
    const network = new Network(this, 'Network');

    // 2. Source: RDS for SQL Server (sample空 or snapshot復元)
    const source = new SourceMssql(this, 'SourceMssql', {
      vpc: network.vpc,
      sourceMode: sourceMode as 'sample' | 'snapshot',
      snapshotIdentifier,
      instanceClass: sourceInstanceClass,
    });

    // 3. Target #1: Aurora PostgreSQL (native, Serverless v2, Data API)
    const targetPg = new TargetAuroraPg(this, 'TargetAuroraPg', {
      vpc: network.vpc,
    });

    // 4. Target #2: Aurora PostgreSQL with Babelfish (Provisioned)
    const targetBabelfish = new TargetBabelfish(this, 'TargetBabelfish', {
      vpc: network.vpc,
    });

    // 5. Workbench EC2 (Strands Agents 実行環境)
    const workbench = new WorkbenchEc2(this, 'WorkbenchEc2', {
      vpc: network.vpc,
      sourceMssqlSg: source.securityGroup,
      targetPgSg: targetPg.securityGroup,
      targetBabelfishSg: targetBabelfish.securityGroup,
      sourceMssqlSecret: source.credentials,
      targetPgSecret: targetPg.credentials,
      targetBabelfishSecret: targetBabelfish.credentials,
      targetPgClusterArn: targetPg.cluster.clusterArn,
      extractionBucketName: source.extractionBucket.bucketName,
    });
    source.extractionBucket.grantReadWrite(workbench.instanceRole);

    // 6. Outputs
    new CfnOutput(this, 'SourceMssqlEndpoint', {
      value: source.instance.dbInstanceEndpointAddress,
      description: 'Source RDS for SQL Server endpoint',
    });
    new CfnOutput(this, 'TargetAuroraPgEndpoint', {
      value: targetPg.cluster.clusterEndpoint.hostname,
      description: 'Target Aurora PostgreSQL (native) endpoint',
    });
    new CfnOutput(this, 'TargetBabelfishEndpoint', {
      value: targetBabelfish.cluster.clusterEndpoint.hostname,
      description: 'Target Aurora PostgreSQL with Babelfish endpoint (PG:5432, TDS:1433)',
    });
    new CfnOutput(this, 'WorkbenchInstanceId', {
      value: workbench.instance.instanceId,
      description: 'Workbench EC2 instance ID (connect via: aws ssm start-session --target <id>)',
    });
    new CfnOutput(this, 'WorkbenchSsmStartSessionCommand', {
      value: `aws ssm start-session --target ${workbench.instance.instanceId} --region ${this.region}`,
      description: 'SSM Session Manager command to connect to the workbench EC2',
    });
    new CfnOutput(this, 'ExtractionBucketName', {
      value: source.extractionBucket.bucketName,
      description: 'S3 bucket for DDL extraction and sample upload',
    });
    new CfnOutput(this, 'SourceMode', {
      value: sourceMode,
      description: 'Source mode (sample or snapshot)',
    });
  }
}
