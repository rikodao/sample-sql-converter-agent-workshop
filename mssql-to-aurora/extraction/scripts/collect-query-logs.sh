#!/usr/bin/env bash
# collect-query-logs.sh (placeholder)
# 実RDS の Extended Events ファイルを S3 にアップロードする。
# rds_upload_to_s3 ストアド経由で行う想定。
#
# 詳細: docs/03-source-extraction.md セクション 3.5 を参照。
set -euo pipefail

: "${MSSQL_HOST:?MSSQL_HOST not set}"
: "${MSSQL_USER:?MSSQL_USER not set}"
: "${MSSQL_PASS:?MSSQL_PASS not set}"
: "${S3_BUCKET:?S3_BUCKET not set}"

sqlcmd -S "$MSSQL_HOST,1433" -U "$MSSQL_USER" -P "$MSSQL_PASS" -C -N <<SQL
EXEC msdb.dbo.rds_upload_to_s3
    @rds_file_path='D:\rdsdbdata\Log\migration_query_capture.xel',
    @s3_arn_to_upload_to='arn:aws:s3:::${S3_BUCKET}/queries/migration_query_capture.xel';
SQL

echo "Uploaded XEL to s3://${S3_BUCKET}/queries/"
