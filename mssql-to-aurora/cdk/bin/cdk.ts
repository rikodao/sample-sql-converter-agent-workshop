#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { MssqlToAuroraStack } from '../lib/mssql-to-aurora-stack';

const app = new cdk.App();

new MssqlToAuroraStack(app, 'MssqlToAuroraStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
  description:
    'MSSQL → Aurora PostgreSQL / Babelfish migration validation environment',
});
