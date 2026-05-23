"""
MSSQL MCP server functions.
pyodbc + Microsoft ODBC Driver 18 経由で Source RDS for SQL Server に接続。
"""
import json
import os
import sys
from typing import Any

import boto3
import pyodbc

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils.logger import get_logger

logger = get_logger("mssql")


SECRET_NAME = os.environ.get(
    "MSSQL_SECRET_NAME", "mssql-to-aurora/source-mssql-credentials"
)
HOST = os.environ.get("MSSQL_HOST")  # Workbench EC2 起動時に環境変数で設定
PORT = int(os.environ.get("MSSQL_PORT", "1433"))
DRIVER = os.environ.get("MSSQL_DRIVER", "ODBC Driver 18 for SQL Server")
DATABASE = os.environ.get("MSSQL_DATABASE", "migration_demo")


def _get_credentials() -> dict[str, str]:
    secrets = boto3.client("secretsmanager")
    raw = secrets.get_secret_value(SecretId=SECRET_NAME)["SecretString"]
    payload = json.loads(raw)
    return {"username": payload["username"], "password": payload["password"]}


def _connect() -> pyodbc.Connection:
    if not HOST:
        raise RuntimeError("MSSQL_HOST environment variable is not set")
    creds = _get_credentials()
    conn_str = (
        f"DRIVER={{{DRIVER}}};"
        f"SERVER={HOST},{PORT};"
        f"DATABASE={DATABASE};"
        f"UID={creds['username']};"
        f"PWD={creds['password']};"
        f"Encrypt=yes;TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str, autocommit=True)


def mssql_execute(sql: str) -> Any:
    """Execute a T-SQL statement on the Source RDS for SQL Server.

    Args:
        sql (str): T-SQL statement (DDL/DML/SELECT) to execute.

    Returns:
        list | dict: rows for SELECT, success message for DDL/DML.
    """
    logger.info(f"Executing on MSSQL: {sql[:200]}{'...' if len(sql) > 200 else ''}")
    conn = _connect()
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        if cursor.description:
            columns = [c[0] for c in cursor.description]
            rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
            return rows
        return {"status": "ok", "rowcount": cursor.rowcount}
    finally:
        conn.close()
