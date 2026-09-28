"""Profile the raw tables: run sql/inspection/raw_profile.sql and count
missing values and full-row duplicates for every raw table.

Results are saved as CSV files in reports/tables/inspection/.
Run src/load_raw.py first.
"""

import pandas as pd

from sql_utils import SQL_DIR, TABLES_DIR, connect, run_named_queries

SQL_FILE = SQL_DIR / "inspection" / "raw_profile.sql"
OUT_DIR = TABLES_DIR / "inspection"


def missing_and_duplicates(conn):
    """Missing (NULL or blank) values per column and full-row duplicates per table."""
    tables = [row[0] for row in conn.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'raw_%' ORDER BY name")]
    missing_rows, duplicate_rows = [], []
    for table in tables:
        total = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        distinct = conn.execute(f"SELECT COUNT(*) FROM (SELECT DISTINCT * FROM {table})").fetchone()[0]
        duplicate_rows.append({"table_name": table, "rows": total, "full_row_duplicates": total - distinct})

        columns = [row[1] for row in conn.execute(f"PRAGMA table_info({table})")]
        for column in columns:
            missing = conn.execute(
                f'SELECT SUM("{column}" IS NULL OR TRIM("{column}") = \'\') FROM {table}').fetchone()[0]
            missing_rows.append({
                "table_name": table, "column_name": column, "rows": total,
                "missing": missing, "missing_pct": round(100 * missing / total, 2),
            })
    return pd.DataFrame(missing_rows), pd.DataFrame(duplicate_rows)


def profile_raw(verbose=True):
    with connect() as conn:
        run_named_queries(conn, SQL_FILE, OUT_DIR, verbose=verbose)

        missing, duplicates = missing_and_duplicates(conn)
        missing.to_csv(OUT_DIR / "missing_values.csv", index=False)
        duplicates.to_csv(OUT_DIR / "full_row_duplicates.csv", index=False)
        if verbose:
            print("\n== missing_values (columns with at least one missing value)")
            print(missing[missing["missing"] > 0].to_string(index=False))
            print("\n== full_row_duplicates")
            print(duplicates.to_string(index=False))


if __name__ == "__main__":
    profile_raw()
