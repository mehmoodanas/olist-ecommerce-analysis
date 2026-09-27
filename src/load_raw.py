"""Load the raw Olist CSV files into SQLite as raw_* tables.

Every column is loaded as text so the raw tables match the CSV files exactly.
Type conversion and cleaning happen later in SQL (sql/cleaning/).
Rerunning replaces the raw tables, so the script is safe to run more than once.
"""

import sqlite3
from pathlib import Path

import pandas as pd

PROJECT_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = PROJECT_DIR / "data" / "raw"
DB_PATH = PROJECT_DIR / "data" / "processed" / "olist.db"

# table name -> CSV file name
RAW_FILES = {
    "raw_orders": "olist_orders_dataset.csv",
    "raw_order_items": "olist_order_items_dataset.csv",
    "raw_order_payments": "olist_order_payments_dataset.csv",
    "raw_order_reviews": "olist_order_reviews_dataset.csv",
    "raw_customers": "olist_customers_dataset.csv",
    "raw_products": "olist_products_dataset.csv",
    "raw_sellers": "olist_sellers_dataset.csv",
    "raw_category_translation": "product_category_name_translation.csv",
}


def check_files_exist():
    missing = [name for name in RAW_FILES.values() if not (RAW_DIR / name).exists()]
    if missing:
        raise FileNotFoundError(
            "Missing raw files in data/raw/: " + ", ".join(missing)
            + "\nDownload and extract the dataset first (see data/README.md)."
        )


def load_raw_tables(db_path=DB_PATH):
    check_files_exist()
    db_path.parent.mkdir(parents=True, exist_ok=True)

    with sqlite3.connect(db_path) as conn:
        for table, file_name in RAW_FILES.items():
            # utf-8-sig removes the byte order mark found in the translation file
            df = pd.read_csv(RAW_DIR / file_name, dtype=str, encoding="utf-8-sig")
            df.to_sql(table, conn, if_exists="replace", index=False)
            print(f"Loaded {table:<26} {len(df):>7,} rows")


if __name__ == "__main__":
    load_raw_tables()
