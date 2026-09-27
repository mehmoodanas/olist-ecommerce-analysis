# Data

## Source

**Brazilian E-Commerce Public Dataset by Olist**
https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

- Publisher: Olist (Kaggle user `olistbr`)
- Licence: [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) (non-commercial use, attribution required, share-alike)
- Last updated on Kaggle: 2021-10-01
- The data is historical and anonymised. Results from this project describe that historical period only.

The raw files are **not** included in this repository. Download them yourself using the steps below.

## Download steps

1. Sign in to Kaggle and open the dataset page above.
2. Click **Download** to get the ZIP file (about 43 MB, usually named `archive.zip`).
3. Place the ZIP in `data/raw/` and extract it there.

## Expected files in `data/raw/`

| File | Used in this project |
|---|---|
| `olist_orders_dataset.csv` | Yes |
| `olist_order_items_dataset.csv` | Yes |
| `olist_order_payments_dataset.csv` | Yes |
| `olist_order_reviews_dataset.csv` | Yes |
| `olist_customers_dataset.csv` | Yes |
| `olist_products_dataset.csv` | Yes |
| `product_category_name_translation.csv` | Yes |
| `olist_sellers_dataset.csv` | Only where useful |
| `olist_geolocation_dataset.csv` | No (not needed for the business questions) |

Raw files are never modified. All cleaning happens in SQLite (see `sql/`).

## Notes on the raw files

- `product_category_name_translation.csv` starts with a UTF-8 byte order mark, so it is read with `utf-8-sig` encoding.
- Two column names in `olist_products_dataset.csv` are misspelled in the source (`product_name_lenght`, `product_description_lenght`). They are kept as-is in the raw tables and renamed during cleaning.
