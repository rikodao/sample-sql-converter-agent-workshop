"""
Babelfish MCP server functions.
Babelfish for Aurora PostgreSQL に対して、TDS:1433 と PG:5432 の両方の接続を提供する。
TDS 経由は MSSQL クライアント互換 (T-SQL を投入)、PG 経由は通常の PL/pgSQL。
"""
import json
import os
import sys
from typing import Any

import boto3
import psycopg
import pyodbc

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils.logger import get_logger

logger = get_logger("babelfish")


SECRET_NAME = os.environ.get(
    "BABELFISH_SECRET_NAME", "mssql-to-aurora/target-babelfish-credentials"
)
HOST = os.environ.get("BABELFISH_HOST")
PORT_TDS = int(os.environ.get("BABELFISH_TDS_PORT", "1433"))
PORT_PG = int(os.environ.get("BABELFISH_PG_PORT", "5432"))
DRIVER = os.environ.get("BABELFISH_TDS_DRIVER", "ODBC Driver 18 for SQL Server")
DBNAME = os.environ.get("BABELFISH_DB", "babelfish_db")


def _get_credentials() -> dict[str, str]:
    secrets = boto3.client("secretsmanager")
    raw = secrets.get_secret_value(SecretId=SECRET_NAME)["SecretString"]
    payload = json.loads(raw)
    return {"username": payload["username"], "password": payload["password"]}


def _connect_tds() -> pyodbc.Connection:
    if not HOST:
        raise RuntimeError("BABELFISH_HOST environment variable is not set")
    creds = _get_credentials()
    conn_str = (
        f"DRIVER={{{DRIVER}}};"
        f"SERVER={HOST},{PORT_TDS};"
        f"UID={creds['username']};"
        f"PWD={creds['password']};"
        f"Encrypt=yes;TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str, autocommit=True)


def _connect_pg() -> psycopg.Connection:
    if not HOST:
        raise RuntimeError("BABELFISH_HOST environment variable is not set")
    creds = _get_credentials()
    return psycopg.connect(
        host=HOST,
        port=PORT_PG,
        dbname=DBNAME,
        user=creds["username"],
        password=creds["password"],
        sslmode="require",
        autocommit=True,
    )


def babelfish_tsql_execute(sql: str) -> Any:
    """Execute T-SQL via TDS:1433 against Babelfish (= MSSQL client compatible).

    Args:
        sql (str): T-SQL statement to execute.

    Returns:
        list | dict: rows or status.
    """
    logger.info(f"[Babelfish/TDS] {sql[:200]}{'...' if len(sql) > 200 else ''}")
    conn = _connect_tds()
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


def babelfish_pg_execute(sql: str) -> Any:
    """Execute PL/pgSQL via PG:5432 against the same Babelfish cluster.

    Args:
        sql (str): PL/pgSQL or standard SQL.

    Returns:
        list | dict
    """
    logger.info(f"[Babelfish/PG] {sql[:200]}{'...' if len(sql) > 200 else ''}")
    conn = _connect_pg()
    try:
        with conn.cursor() as cursor:
            cursor.execute(sql)
            if cursor.description:
                columns = [c.name for c in cursor.description]
                rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
                return rows
            return {"status": "ok", "rowcount": cursor.rowcount}
    finally:
        conn.close()
