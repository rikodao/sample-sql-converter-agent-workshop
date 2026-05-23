"""FastMCP server exposing all DB tools.

Tools:
  - run_mssql_sql(sql)       : Source RDS for SQL Server
  - run_babelfish_tsql(sql)  : Babelfish via TDS:1433
  - run_babelfish_pg(sql)    : Babelfish via PG:5432
  - run_postgres_sql(sql)    : Aurora PG native (Data API)
  - create_directory(path)   : mkdir -p
"""
import os
import sys

from mcp.server.fastmcp import FastMCP

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from babelfish import babelfish_pg_execute, babelfish_tsql_execute
from mssql import mssql_execute
from postgres import postgres_execute
from shell import mkdir_p

from utils.logger import get_logger

logger = get_logger("mcp.server")
mcp = FastMCP("mssql-to-aurora")


@mcp.tool()
def run_mssql_sql(sql: str):
    """Execute T-SQL on Source RDS for SQL Server.

    Args:
        sql (str): T-SQL statement.

    Returns:
        Query results (list of dicts) or status.
    """
    return mssql_execute(sql)


@mcp.tool()
def run_babelfish_tsql(sql: str):
    """Execute T-SQL on Babelfish via TDS:1433 (MSSQL client compatible).

    Args:
        sql (str): T-SQL statement.

    Returns:
        Query results (list of dicts) or status.
    """
    return babelfish_tsql_execute(sql)


@mcp.tool()
def run_babelfish_pg(sql: str):
    """Execute PL/pgSQL on Babelfish via PG:5432.

    Args:
        sql (str): PL/pgSQL or standard SQL.

    Returns:
        Query results (list of dicts) or status.
    """
    return babelfish_pg_execute(sql)


@mcp.tool()
def run_postgres_sql(sql: str):
    """Execute PL/pgSQL on the target Aurora PostgreSQL (native) via RDS Data API.

    Args:
        sql (str): PL/pgSQL or standard SQL.

    Returns:
        RDS Data API response.
    """
    return postgres_execute(sql)


@mcp.tool()
def create_directory(path: str):
    """Create directory and all parents (mkdir -p).

    Args:
        path (str): Directory path.

    Returns:
        Status string.
    """
    return mkdir_p(path)


if __name__ == "__main__":
    mcp.run(transport="stdio")
