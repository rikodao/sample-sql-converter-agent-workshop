"""Quick connectivity test for all 3 DBs."""
import os
import sys

sys.path.insert(0, "mcpserver")

from mssql import mssql_execute
from postgres import postgres_execute
from babelfish import babelfish_pg_execute, babelfish_tsql_execute


def section(title):
    print()
    print("=" * 60)
    print(title)
    print("=" * 60)


def main():
    section("[1/4] Source MSSQL (pyodbc/TDS:1433)")
    r = mssql_execute(
        "SELECT @@VERSION AS v, "
        "(SELECT COUNT(*) FROM sys.objects WHERE schema_id=SCHEMA_ID('dbo') "
        "AND type IN ('P','FN','IF','TF','TR','V')) AS objects"
    )
    print(r)

    section("[2/4] Aurora PostgreSQL native (Data API)")
    r = postgres_execute("SELECT version() AS v")
    print(r)

    section("[3/4] Babelfish PG (psycopg/5432)")
    try:
        r = babelfish_pg_execute("SELECT version() AS v")
        print(r)
    except Exception as e:
        print(f"FAILED: {e}")

    section("[4/4] Babelfish TDS (pyodbc/1433)")
    try:
        r = babelfish_tsql_execute("SELECT @@VERSION AS v")
        print(r)
    except Exception as e:
        print(f"FAILED: {e}")

    print()
    print("All connectivity checks complete.")


if __name__ == "__main__":
    main()
