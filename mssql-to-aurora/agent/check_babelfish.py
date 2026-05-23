"""Check Babelfish status from the PG side."""
import os
import sys

sys.path.insert(0, "mcpserver")

from babelfish import babelfish_pg_execute


def main():
    print("=== pg_settings (babelfish/tds) ===")
    r = babelfish_pg_execute(
        "SELECT name, setting FROM pg_settings "
        "WHERE name LIKE 'babelfishpg%' OR name LIKE 'rds.babelfish%' "
        "ORDER BY name"
    )
    for row in r:
        print(f"  {row['name']:50s} = {row['setting']}")

    print()
    print("=== pg_extension (babelfish*) ===")
    r = babelfish_pg_execute(
        "SELECT extname, extversion FROM pg_extension WHERE extname LIKE 'babelfish%'"
    )
    print(r)

    print()
    print("=== List of databases ===")
    r = babelfish_pg_execute(
        "SELECT datname FROM pg_database ORDER BY datname"
    )
    print(r)

    print()
    print("=== Current connection ===")
    r = babelfish_pg_execute(
        "SELECT current_database() AS db, current_user AS user"
    )
    print(r)


if __name__ == "__main__":
    main()
