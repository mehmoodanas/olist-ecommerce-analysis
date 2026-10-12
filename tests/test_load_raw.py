"""Tests for the raw loader using small synthetic CSV files."""

import sqlite3

import pytest

import load_raw


def test_check_files_exist_reports_missing_files(tmp_path, monkeypatch):
    monkeypatch.setattr(load_raw, "RAW_DIR", tmp_path)
    with pytest.raises(FileNotFoundError, match="Missing raw files"):
        load_raw.check_files_exist()


def test_load_raw_tables_loads_everything_as_text(tmp_path, monkeypatch):
    raw_dir = tmp_path / "raw"
    raw_dir.mkdir()
    for file_name in load_raw.RAW_FILES.values():
        # leading zeros must survive: everything is loaded as text
        (raw_dir / file_name).write_text("id,value\n001,10\n002,20\n", encoding="utf-8-sig")
    monkeypatch.setattr(load_raw, "RAW_DIR", raw_dir)

    db_path = tmp_path / "processed" / "test.db"
    load_raw.load_raw_tables(db_path)
    load_raw.load_raw_tables(db_path)  # rerunning must replace tables, not duplicate rows

    with sqlite3.connect(db_path) as conn:
        for table in load_raw.RAW_FILES:
            rows = conn.execute(f"SELECT id FROM {table} ORDER BY id").fetchall()
            assert rows == [("001",), ("002",)]
