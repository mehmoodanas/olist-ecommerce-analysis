"""Unit tests for the SQL helpers. They use tiny in-memory data, not the Olist files."""

import sqlite3

import pandas as pd
import pytest

import sql_utils


def test_read_named_queries_splits_on_markers(tmp_path):
    sql_file = tmp_path / "q.sql"
    sql_file.write_text(
        "-- header comment\n"
        "-- name: first\nSELECT 1 AS a;\n\n"
        "-- name: second\nSELECT 2 AS b;\n",
        encoding="utf-8",
    )
    queries = sql_utils.read_named_queries(sql_file)
    assert list(queries) == ["first", "second"]
    assert queries["first"] == "SELECT 1 AS a;"
    assert queries["second"] == "SELECT 2 AS b;"


def test_run_named_queries_saves_csv_and_returns_results(tmp_path):
    sql_file = tmp_path / "q.sql"
    sql_file.write_text("-- name: totals\nSELECT 3 AS n;\n", encoding="utf-8")
    out_dir = tmp_path / "out"
    with sqlite3.connect(":memory:") as conn:
        results = sql_utils.run_named_queries(conn, sql_file, out_dir, verbose=False)
    assert results["totals"]["n"].tolist() == [3]
    saved = pd.read_csv(out_dir / "totals.csv")
    assert saved["n"].tolist() == [3]


def test_run_scripts_in_folder_runs_in_file_name_order(tmp_path):
    (tmp_path / "02_second.sql").write_text("INSERT INTO t VALUES ('second');", encoding="utf-8")
    (tmp_path / "01_first.sql").write_text(
        "CREATE TABLE t (v TEXT); INSERT INTO t VALUES ('first');", encoding="utf-8"
    )
    with sqlite3.connect(":memory:") as conn:
        sql_utils.run_scripts_in_folder(conn, tmp_path)
        rows = conn.execute("SELECT v FROM t ORDER BY rowid").fetchall()
    assert rows == [("first",), ("second",)]


def test_connect_raises_when_database_missing(tmp_path):
    with pytest.raises(FileNotFoundError):
        sql_utils.connect(tmp_path / "missing.db")
