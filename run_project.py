"""Rebuild the whole project from the downloaded Olist CSV files.

Usage (from the project folder):
    python run_project.py

Steps:
    1. Load raw CSVs into SQLite            (src/load_raw.py)
    2. Profile the raw tables               (sql/inspection/raw_profile.sql)
    3. Clean the data                       (sql/cleaning/*.sql)
    4. Summarise and check the cleaning     (sql/inspection/cleaning_summary.sql)

Every step rebuilds its tables and output files, so the script is safe to rerun.
It stops with an error if a check fails.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "src"))

from load_raw import load_raw_tables  # noqa: E402
from profile_raw import profile_raw  # noqa: E402
from sql_utils import SQL_DIR, TABLES_DIR, connect, run_named_queries, run_scripts_in_folder  # noqa: E402


class CheckFailed(Exception):
    pass


def check_cleaning(results):
    """Cleaning must not add or lose rows."""
    counts = results["row_counts_raw_vs_clean"]
    mismatched = counts[counts["raw_rows"] != counts["clean_rows"]]
    if not mismatched.empty:
        raise CheckFailed("Row counts changed during cleaning:\n" + mismatched.to_string(index=False))
    print("Check passed: raw and clean row counts match for every table.")


def main():
    print("\n[1/4] Loading raw CSV files")
    load_raw_tables()

    print("\n[2/4] Profiling raw tables")
    profile_raw(verbose=False)
    print(f"Saved results to {TABLES_DIR / 'inspection'}")

    with connect() as conn:
        print("\n[3/4] Cleaning")
        run_scripts_in_folder(conn, SQL_DIR / "cleaning")

        print("\n[4/4] Cleaning summary")
        results = run_named_queries(conn, SQL_DIR / "inspection" / "cleaning_summary.sql",
                                    TABLES_DIR / "cleaning", verbose=False)
        print(f"Saved results to {TABLES_DIR / 'cleaning'}")
        check_cleaning(results)

    print("\nDone.")


if __name__ == "__main__":
    try:
        main()
    except (CheckFailed, FileNotFoundError) as error:
        print(f"\nSTOPPED: {error}")
        sys.exit(1)
