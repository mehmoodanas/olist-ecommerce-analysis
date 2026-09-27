"""Profile the raw tables: run sql/inspection/raw_profile.sql and count
missing values and full-row duplicates for every raw table.

Results are saved as CSV files in reports/tables/inspection/.
Run src/load_raw.py first.
"""

import re
import sqlite3
from pathlib import Path

import pandas as pd

PROJECT_DIR = Path(__file__).resolve().parents[1]
DB_PATH = PROJECT_DIR / "data" / "processed" / "olist.db"
SQL_FILE = PROJECT_DIR / "sql" / "inspection" / "raw_profile.sql"
OUT_DIR = PROJECT_DIR / "reports" / "tables" / "inspection"


def read_named_queries(sql_file):
    """Split a SQL file into {name: query} using '-- name: <name>' markers."""
    parts = re.split(r"^-- name:\s*(\w+)\s*$", sql_file.read_text(encoding="utf-8"), flags=re.M)
    # parts = [header, name1, query1, name2, query2, ...]
    return {name: query.strip() for name, query in zip(parts[1::2], parts[2::2])}


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


def profile_raw(db_path=DB_PATH):
    if not db_path.exists():
        raise FileNotFoundError(f"{db_path} not found. Run src/load_raw.py first.")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    with sqlite3.connect(db_path) as conn:
        for name, query in read_named_queries(SQL_FILE).items():
            result = pd.read_sql_query(query, conn)
            result.to_csv(OUT_DIR / f"{name}.csv", index=False)
            print(f"\n== {name}\n{result.to_string(index=False)}")

        missing, duplicates = missing_and_duplicates(conn)
        missing.to_csv(OUT_DIR / "missing_values.csv", index=False)
        duplicates.to_csv(OUT_DIR / "full_row_duplicates.csv", index=False)
        print("\n== missing_values (columns with at least one missing value)")
        print(missing[missing["missing"] > 0].to_string(index=False))
        print("\n== full_row_duplicates")
        print(duplicates.to_string(index=False))


if __name__ == "__main__":
    profile_raw()
