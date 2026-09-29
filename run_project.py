"""Rebuild the whole project from the downloaded Olist CSV files.

Usage (from the project folder):
    python run_project.py

Steps:
    1. Load raw CSVs into SQLite            (src/load_raw.py)
    2. Profile the raw tables               (sql/inspection/raw_profile.sql)
    3. Clean the data                       (sql/cleaning/*.sql)
    4. Summarise and check the cleaning     (sql/inspection/cleaning_summary.sql)
    5. Build reporting models               (sql/models/*.sql)
    6. Validate the models                  (sql/validation/*.sql)
    7. Run the analysis queries             (sql/analysis/*.sql)
    8. Create the charts                    (src/make_charts.py)

Every step rebuilds its tables and output files, so the script is safe to rerun.
It stops with an error if a check fails.
"""

import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent / "src"))

from load_raw import load_raw_tables  # noqa: E402
from make_charts import make_charts  # noqa: E402
from profile_raw import profile_raw  # noqa: E402
from sql_utils import SQL_DIR, TABLES_DIR, connect, run_named_queries, run_scripts_in_folder  # noqa: E402

STEPS = 8
# money totals are compared after rounding, so allow one cent of difference
TOLERANCE = 0.01


class CheckFailed(Exception):
    pass


def step(number, title):
    print(f"\n[{number}/{STEPS}] {title}")


def check_cleaning(results):
    """Cleaning must not add or lose rows."""
    counts = results["row_counts_raw_vs_clean"]
    mismatched = counts[counts["raw_rows"] != counts["clean_rows"]]
    if not mismatched.empty:
        raise CheckFailed("Row counts changed during cleaning:\n" + mismatched.to_string(index=False))
    print("Check passed: raw and clean row counts match for every table.")


def validate_models(conn):
    """Run every validation query and stop if any actual value differs from expected."""
    out_dir = TABLES_DIR / "validation"
    checks = []
    for sql_file in sorted((SQL_DIR / "validation").glob("*.sql")):
        results = run_named_queries(conn, sql_file, out_dir, verbose=False)
        for name, result in results.items():
            checks.append(result.assign(query=name))
    checks = pd.concat(checks, ignore_index=True)
    checks["passed"] = (checks["expected"] - checks["actual"]).abs() <= TOLERANCE
    checks.to_csv(out_dir / "validation_summary.csv", index=False)

    failed = checks[~checks["passed"]]
    if not failed.empty:
        raise CheckFailed("Validation failed:\n" + failed.to_string(index=False))
    print(f"Check passed: all {len(checks)} validation checks (see {out_dir / 'validation_summary.csv'}).")


def run_analysis(conn):
    """Run every named query in sql/analysis/ and save it to reports/tables/analysis/."""
    out_dir = TABLES_DIR / "analysis"
    count = 0
    for sql_file in sorted((SQL_DIR / "analysis").glob("*.sql")):
        results = run_named_queries(conn, sql_file, out_dir, verbose=False)
        count += len(results)
        print(f"Ran {sql_file.name}: {', '.join(results)}")
    print(f"Saved {count} result tables to {out_dir}")


def main():
    step(1, "Loading raw CSV files")
    load_raw_tables()

    step(2, "Profiling raw tables")
    profile_raw(verbose=False)
    print(f"Saved results to {TABLES_DIR / 'inspection'}")

    with connect() as conn:
        step(3, "Cleaning")
        run_scripts_in_folder(conn, SQL_DIR / "cleaning")

        step(4, "Cleaning summary")
        results = run_named_queries(conn, SQL_DIR / "inspection" / "cleaning_summary.sql",
                                    TABLES_DIR / "cleaning", verbose=False)
        print(f"Saved results to {TABLES_DIR / 'cleaning'}")
        check_cleaning(results)

        step(5, "Building reporting models")
        run_scripts_in_folder(conn, SQL_DIR / "models")

        step(6, "Validating models")
        validate_models(conn)

        step(7, "Running analysis queries")
        run_analysis(conn)

    step(8, "Creating charts")
    make_charts()

    print("\nDone.")


if __name__ == "__main__":
    try:
        main()
    except (CheckFailed, FileNotFoundError) as error:
        print(f"\nSTOPPED: {error}")
        sys.exit(1)
