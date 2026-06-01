"""
Aurora PostgreSQL (native) MCP server functions.
RDS Data API 経由で接続。既存 Oracle 側 mcpserver/postgres.py を踏襲。
"""
import json
import os
import sys
from typing import Any

import boto3

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils.logger import get_logger

logger = get_logger("postgres")

SECRET_NAME = os.environ.get(
    "AURORA_PG_SECRET_NAME", "mssql-to-aurora/target-pg-credentials"
)

_sts = boto3.client("sts")
_account_id = _sts.get_caller_identity()["Account"]
_region = _sts.meta.region_name


def _get_credentials() -> dict[str, str]:
    secrets = boto3.client("secretsmanager")
    resp = secrets.get_secret_value(SecretId=SECRET_NAME)
    payload = json.loads(resp["SecretString"])
    cluster_arn = (
        f"arn:aws:rds:{_region}:{_account_id}:cluster:{payload['dbClusterIdentifier']}"
    )
    return {
        "cluster_arn": cluster_arn,
        "secret_arn": resp["ARN"],
        "database": os.environ.get("AURORA_PG_DBNAME", "postgres"),
    }


def postgres_execute(sql: str) -> Any:
    """Execute PL/pgSQL on the target Aurora PostgreSQL (native) via RDS Data API.

    Args:
        sql (str): PL/pgSQL or standard SQL.

    Returns:
        dict: Data API response.
    """
    logger.info(f"[PG/native] {sql[:200]}{'...' if len(sql) > 200 else ''}")
    creds = _get_credentials()
    rds_data = boto3.client("rds-data")
    response = rds_data.execute_statement(
        resourceArn=creds["cluster_arn"],
        secretArn=creds["secret_arn"],
        database=creds["database"],
        sql=sql,
    )
    response.pop("ResponseMetadata", None)
    return response
