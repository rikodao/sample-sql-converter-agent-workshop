"""Initialize Babelfish extension on the cluster."""
import os
import sys

sys.path.insert(0, "mcpserver")

from babelfish import babelfish_pg_execute


def main():
    print("=== Before init ===")
    r = babelfish_pg_execute(
        "SELECT extname, extversion FROM pg_extension WHERE extname LIKE 'babelfish%'"
    )
    print(r)

    print()
    print("=== Granting babelfish_superuser to babelfish_user ===")
    # AWSのマネージドロール: rds_superuser, rds_replication, rds_iam, rds_password 等
    # Babelfish: babelfish_superuser ロールが必要
    try:
        r = babelfish_pg_execute("GRANT rds_superuser TO babelfish_user")
        print(f"granted rds_superuser: {r}")
    except Exception as e:
        print(f"already had or N/A: {e}")

    print()
    print("=== Creating extension babelfishpg_tds (CASCADE) ===")
    try:
        r = babelfish_pg_execute(
            "CREATE EXTENSION IF NOT EXISTS \"babelfishpg_tds\" CASCADE"
        )
        print(f"created: {r}")
    except Exception as e:
        print(f"FAILED: {e}")

    print()
    print("=== After init: pg_extension ===")
    r = babelfish_pg_execute(
        "SELECT extname, extversion FROM pg_extension WHERE extname LIKE 'babelfish%' ORDER BY extname"
    )
    for row in r:
        print(f"  {row}")

    print()
    print("=== babelfishpg_tsql settings ===")
    r = babelfish_pg_execute(
        "SELECT name, setting FROM pg_settings WHERE name LIKE 'babelfishpg_tsql%' ORDER BY name"
    )
    for row in r:
        print(f"  {row['name']:50s} = {row['setting']}")


if __name__ == "__main__":
    main()
