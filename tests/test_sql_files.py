"""Structure checks on the project's SQL files (no raw data needed)."""

import sqlite3

import pytest

import sql_utils

SQL_DIR = sql_utils.SQL_DIR
SCRIPT_FOLDERS = ["cleaning", "models"]
NAMED_FOLDERS = ["analysis", "validation"]


def sql_files(folder):
    return sorted((SQL_DIR / folder).glob("*.sql"))


@pytest.mark.parametrize("folder", SCRIPT_FOLDERS + NAMED_FOLDERS)
def test_folder_has_sql_files(folder):
    assert sql_files(folder), f"no SQL files in sql/{folder}"


@pytest.mark.parametrize("folder", SCRIPT_FOLDERS)
def test_script_files_are_complete_statements(folder):
    for sql_file in sql_files(folder):
        text = sql_file.read_text(encoding="utf-8").strip()
        assert text, f"{sql_file.name} is empty"
        assert sqlite3.complete_statement(text), f"{sql_file.name} ends mid-statement"


@pytest.mark.parametrize("folder", NAMED_FOLDERS)
def test_named_query_files_have_unique_complete_queries(folder):
    seen = {}
    for sql_file in sql_files(folder):
        text = sql_file.read_text(encoding="utf-8")
        queries = sql_utils.read_named_queries(sql_file)
        assert queries, f"{sql_file.name} has no '-- name:' queries"
        assert text.count("-- name:") == len(queries), f"{sql_file.name}: marker not parsed"
        for name, query in queries.items():
            assert name not in seen, f"query name {name} used in {seen[name]} and {sql_file.name}"
            seen[name] = sql_file.name
            assert query, f"{sql_file.name}:{name} is empty"
            assert sqlite3.complete_statement(query + "
;")


def test_validation_queries_return_check_columns():
    """Validation queries must expose check_name, expected and actual (run_project.py relies on it)."""
    for sql_file in sql_files("validation"):
        for name, query in sql_utils.read_named_queries(sql_file).items():
            for column in ("check_name", "expected", "actual"):
                assert column in query, f"{sql_file.name}:{name} does not select {column}"
