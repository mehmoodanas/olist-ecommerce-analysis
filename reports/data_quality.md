# Data Quality Report

This report explains how the raw Olist tables were cleaned, what problems were found and what remains unresolved. All counts come from running `python run_project.py`. The supporting result tables are in [`reports/tables/cleaning/`](tables/cleaning/) and [`reports/tables/inspection/`](tables/inspection/).

## Summary

- The raw files are kept unchanged. Cleaning happens in SQL ([`sql/cleaning/`](../sql/cleaning/)) and writes new `clean_*` tables.
- **No rows are deleted.** Unusual records get a flag column (`flag_* = 1`), and later steps decide whether to include them. A check in `run_project.py` stops the pipeline if raw and clean row counts ever differ.
- The data is in good shape overall: every date parses, every key is unique, there are no full-row duplicates and no orphan foreign keys. The main issues are order-status gaps, a small number of impossible timestamp sequences, and missing product categories.

| Table | Raw rows | Clean rows |
|---|---|---|
| orders | 99,441 | 99,441 |
| order_items | 112,650 | 112,650 |
| order_payments | 103,886 | 103,886 |
| order_reviews | 99,224 | 99,224 |
| customers | 99,441 | 99,441 |
| products | 32,951 | 32,951 |
| sellers | 3,095 | 3,095 |

## Cleaning rules

### 1. Date parsing

- All timestamps are in `YYYY-MM-DD HH:MM:SS` format. SQLite stores them as text, and `datetime()` is applied so any invalid value would become NULL. **No invalid timestamps were found** in any date column.
- `order_estimated_delivery_date` never has a time part, so it is stored as a date (`YYYY-MM-DD`).
- `purchase_date` and `purchase_month` (`YYYY-MM`) are added to make monthly analysis simpler.

### 2. Order status groups and exclusions

| Status group | Statuses | Orders | Meaning |
|---|---|---|---|
| delivered | delivered | 96,478 | Reached the customer |
| in_progress | shipped (1,107), invoiced (314), processing (301), created (5), approved (2) | 1,729 | Not delivered when the data was extracted |
| not_fulfilled | canceled (625), unavailable (609) | 1,234 | Will not be delivered |

Rules used in later stages:

- **Sales and order metrics use delivered orders only.** In-progress orders could still be canceled, and not-fulfilled orders are not completed sales. The exact definition is written in `docs/metric_definitions.md`.
- **Delivery metrics use `is_valid_delivery = 1`**: delivered status, a customer delivery date exists, and it is not earlier than the purchase. This covers **96,470** orders (96,478 delivered minus 8 without a delivery date).

### 3. Missing delivery timestamps

2,965 orders have no customer delivery date. This is **not** treated as 2,965 errors:

| Case | Orders | Treatment |
|---|---|---|
| Not delivered yet or never delivered (in_progress / not_fulfilled) | 2,957 | Expected. No action. |
| Status is delivered but no delivery date | 8 | Real data problem. Flagged `flag_delivered_missing_date`, excluded from delivery metrics, still counted as delivered orders for sales. |

The reverse also occurs: **6 canceled orders have a customer delivery date** (purchases from 2016-10-03 to 2018-02-19). The status and the date contradict each other, and it is not possible to know which is correct. They are flagged `flag_not_delivered_but_has_date` and kept out of delivery metrics because their status is not delivered.

### 4. Other missing timestamps

160 orders have no approval timestamp: 141 canceled, 5 created and 14 delivered. For canceled and created orders this is expected (payment was never approved). The 14 delivered orders are flagged `flag_missing_approval`. The approval time is not used in any metric, so they stay in the analysis.

### 5. Invalid timestamp sequences

| Check | Orders | Treatment |
|---|---|---|
| Handed to carrier before purchase | 166 (165 delivered, 1 shipped) | Flagged `flag_carrier_before_purchase` |
| Delivered to customer before handed to carrier | 23 (all delivered) | Flagged `flag_delivered_before_carrier` |
| Approved before purchase | 0 | — |
| Delivered to customer before purchase | 0 | — |

For the 166 orders, the carrier date is on average 26.0 hours before the purchase, and up to 171.2 days before. This points to recording errors in the carrier date. Because of this, **the carrier date is not used in the core delivery metrics**. Delivery time is measured from purchase to customer delivery, and both of those timestamps are always in the correct order. The flagged orders therefore stay in the analysis.

### 6. Missing and untranslated product categories

| Rule | Products | Order items | Item price total |
|---|---|---|---|
| Translated from the translation file | 32,328 (71 categories) | 111,023 | 13,406,593.94 |
| Translated by hand (2 categories missing from the file) | 13 | 24 | 5,514.48 |
| No category, labelled `unknown` | 610 | 1,603 | 179,535.28 |

- The two categories missing from the translation file are translated by hand in `sql/cleaning/06_clean_products.sql`: `pc_gamer` → `pc_gamer`, and `portateis_cozinha_e_preparadores_de_alimentos` → `portable_kitchen_and_food_preparers`.
- Products without a category are **kept** as `unknown` so their sales are not lost. They will be shown as their own group in category analysis.
- The 610 products with no category also have no name length, description length or photo count. These columns are not used in the analysis.
- 4 products have a weight of 0 g, which is not possible, and 2 have no size or weight at all. They are flagged (`flag_zero_weight`) and kept. Weight is not used in the business questions.

### 7. Duplicates

- No full-row duplicates in any table.
- All primary keys are unique (checked in `reports/tables/inspection/row_counts_and_keys.csv`).
- `review_id` alone is not unique: 789 review ids are linked to 2 or 3 orders. `review_id` + `order_id` is unique, so these are not duplicates. They are handled in the order-level model, where one review per order is chosen.
- One person can have several `customer_id` values (96,096 unique people for 99,441 customer ids). This is how the source system works, not a duplication error.

### 8. Invalid or unexpected values

| Check | Rows | Treatment |
|---|---|---|
| Item price ≤ 0 | 0 | — |
| Order items with freight of 0 | 383 | Kept and flagged. Free shipping is plausible. |
| Payments with value 0 | 9 | Kept and flagged. 6 are vouchers and 3 are `not_defined`. |
| Payments with 0 instalments | 2 | Kept and flagged. |
| Payment type `not_defined` | 3 | Kept and flagged. All 3 belong to canceled orders, so they do not affect delivered-order metrics. |
| Review score outside 1–5 | 0 | — |
| City or state with extra spaces or wrong case | 0 | Trim and case rules applied as a safeguard. |

### 9. Outliers

Item prices are skewed: the median is 74.99, the 75th percentile 134.90, the 99th percentile 890.00 and the maximum 6,735.00. 844 items cost more than 1,000.

**No price outliers are removed.** High prices belong to real products and are valid sales. Removing them would understate sales value. Where averages could be distorted, later stages will also report medians.

## Orders without items, payments or reviews

| Check | Orders | Notes |
|---|---|---|
| No items | 775 | 603 unavailable, 164 canceled, 5 created, 2 invoiced, 1 shipped. No delivered order is missing items. |
| No payment record | 1 | A delivered order. Its items count towards merchandise sales; it has no payment value. |
| No review | 768 | Review metrics will report coverage and sample sizes. |

## Unresolved limitations

1. **Carrier timestamps are unreliable** for at least 189 orders (166 + 23), and it is unknown whether other carrier dates are slightly wrong too. The analysis avoids depending on them.
2. **8 delivered orders have no delivery date**, and **6 canceled orders have one**. The correct status or date cannot be recovered from the data.
3. **610 products (1,603 order items, 179,535.28 in item price) have no category.** Category shares are calculated with `unknown` as its own group. The true category of these sales is unknown.
4. **Boundary months are incomplete.** 2016-09 to 2016-12 and 2018-09 to 2018-10 have very few orders (2016-11 has none). They will be excluded from growth comparisons.
5. **Currency is not stated** in the files. Values are assumed to be Brazilian reais (BRL).
6. **Payment value and merchandise value measure different things.** Payments are expected to cover freight and may include other charges. The analysis found that payment equals merchandise + freight to the cent for 96,099 of 96,477 delivered orders with a payment record (99.61%); the net difference of 2,831.48 comes mostly from credit-card orders paid in instalments (see `docs/metric_definitions.md`). The values are kept separate, not forced to match.
7. The data is **historical and anonymised**. It describes Olist's marketplace between 2016 and 2018, not its current state.
