"""Shared helpers for running the project's SQL files against SQLite."""

import re
import sqlite3
from pathlib import Path

import pandas as pd

PROJECT_DIR = Path(__file__).resolve().parents[1]
DB_PATH = PROJECT_DIR / "data" / "processed" / "olist.db"
SQL_DIR = PROJECT_DIR / "sql"
TABLES_DIR = PROJECT_DIR / "reports" / "tables"


def connect(db_path=DB_PATH):
    if not db_path.exists():
        raise FileNotFoundError(f"{db_path} not found. Run src/load_raw.py first.")
    return sqlite3.connect(db_path)


def run_script(conn, sql_file):
    """Execute every statement in a SQL file (used for scripts that build tables)."""
    conn.executescript(Path(sql_file).read_text(encoding="utf-8"))
    conn.commit()


def run_scripts_in_folder(conn, folder):
    """Run all .sql files in a folder in file-name order (01_..., 02_..., ...)."""
    files = sorted(Path(folder).glob("*.sql"))
    for sql_file in files:
        run_script(conn, sql_file)
        print(f"Ran {sql_file.relative_to(PROJECT_DIR)}")
    return files


def read_named_queries(sql_file):
    """Split a SQL file into {name: query} using '-- name: <name>' markers."""
    text = Path(sql_file).read_text(encoding="utf-8")
    parts = re.split(r"^-- name:\s*(\w+)\s*$", text, flags=re.M)
    # parts = [header, name1, query1, name2, query2, ...]
    return {name: query.strip() for name, query in zip(parts[1::2], parts[2::2])}


def run_named_queries(conn, sql_file, out_dir, verbose=True):
    """Run each named query, save it as <out_dir>/<name>.csv and return the results."""
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    results = {}
    for name, query in read_named_queries(sql_file).items():
        result = pd.read_sql_query(query, conn)
        result.to_csv(out_dir / f"{name}.csv", index=False)
        results[name] = result
        if verbose:
            print(f"\n== {name}\n{result.to_string(index=False)}")
    return results
