import {
  FlowLogDestination,
  FlowLogTrafficType,
  SubnetType,
  Vpc,
} from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

/**
 * MSSQL → Aurora 移行検証用の VPC。
 * SSH は使用せず、Workbench EC2 への接続は SSM Session Manager 経由のみとする。
 * したがって IC Endpoint も不要。
 */
export class Network extends Construct {
  readonly vpc: Vpc;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    this.vpc = new Vpc(this, 'Vpc', {
      maxAzs: 2,
      natGateways: 1,
      subnetConfiguration: [
        { cidrMask: 24, name: 'public', subnetType: SubnetType.PUBLIC },
        { cidrMask: 24, name: 'private', subnetType: SubnetType.PRIVATE_WITH_EGRESS },
        { cidrMask: 24, name: 'isolated', subnetType: SubnetType.PRIVATE_ISOLATED },
      ],
      flowLogs: {
        cw: {
          destination: FlowLogDestination.toCloudWatchLogs(),
          trafficType: FlowLogTrafficType.REJECT,
        },
      },
    });
  }
}
