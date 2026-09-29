# Data Dictionary

This document describes the raw Olist tables used in the project: what one row means (grain), the keys, row counts, date coverage, data quality observations and the join risks between tables.

All numbers come from `src/profile_raw.py`, which runs [`sql/inspection/raw_profile.sql`](../sql/inspection/raw_profile.sql). The full outputs are in [`reports/tables/inspection/`](../reports/tables/inspection/).

Money columns (`price`, `freight_value`, `payment_value`) have no currency stated in the files. They are assumed to be Brazilian reais (BRL) because the marketplace is Brazilian.

## Table overview

| Raw table | Source file | Grain (one row = ) | Primary key | Rows |
|---|---|---|---|---|
| `raw_orders` | olist_orders_dataset.csv | one order | `order_id` | 99,441 |
| `raw_order_items` | olist_order_items_dataset.csv | one item line within an order | `order_id` + `order_item_id` | 112,650 |
| `raw_order_payments` | olist_order_payments_dataset.csv | one payment record for an order | `order_id` + `payment_sequential` | 103,886 |
| `raw_order_reviews` | olist_order_reviews_dataset.csv | one review linked to one order | `review_id` + `order_id` (see note) | 99,224 |
| `raw_customers` | olist_customers_dataset.csv | one customer id (created per order) | `customer_id` | 99,441 |
| `raw_products` | olist_products_dataset.csv | one product | `product_id` | 32,951 |
| `raw_sellers` | olist_sellers_dataset.csv | one seller | `seller_id` | 3,095 |
| `raw_category_translation` | product_category_name_translation.csv | one category name | `product_category_name` | 71 |

The geolocation file is not loaded because none of the business questions need latitude/longitude.

All primary keys listed above were checked and are unique. No table contains full-row duplicates.

## Relationships

```
customers (customer_id) 1 ── 1 orders (order_id) 1 ── many order_items ── many:1 products ── many:1 category_translation
                                                  │                    └─ many:1 sellers
                                                  ├── many order_payments
                                                  └── many order_reviews
```

| Relationship | Type | Orphan rows found |
|---|---|---|
| order_items → orders | many-to-one | 0 |
| order_items → products | many-to-one | 0 |
| order_items → sellers | many-to-one | 0 |
| order_payments → orders | many-to-one | 0 |
| order_reviews → orders | many-to-one | 0 |
| orders → customers | one-to-one | 0 |

Parents without children:

| Check | Rows |
|---|---|
| Orders with no items | 775 |
| Orders with no payment record | 1 |
| Orders with no review | 768 |
| Products whose category has no English translation | 13 (categories `pc_gamer` and `portateis_cozinha_e_preparadores_de_alimentos`) |

## Tables in detail

### raw_orders

| Column | Description | Missing |
|---|---|---|
| `order_id` | Order identifier (primary key) | 0 |
| `customer_id` | Links to `raw_customers`; unique per order | 0 |
| `order_status` | Current status of the order | 0 |
| `order_purchase_timestamp` | When the customer placed the order | 0 |
| `order_approved_at` | When payment was approved | 160 |
| `order_delivered_carrier_date` | When the order was handed to the carrier | 1,783 |
| `order_delivered_customer_date` | When the customer received the order | 2,965 |
| `order_estimated_delivery_date` | Delivery date promised at purchase (date only, time is always 00:00:00) | 0 |

Order status counts and missing timestamps:

| Status | Orders | Missing approval | Missing carrier date | Missing customer delivery | Orders without items |
|---|---|---|---|---|---|
| delivered | 96,478 | 14 | 2 | 8 | 0 |
| shipped | 1,107 | 0 | 0 | 1,107 | 1 |
| canceled | 625 | 141 | 550 | 619 | 164 |
| unavailable | 609 | 0 | 609 | 609 | 603 |
| invoiced | 314 | 0 | 314 | 314 | 2 |
| processing | 301 | 0 | 301 | 301 | 0 |
| created | 5 | 5 | 5 | 5 | 5 |
| approved | 2 | 0 | 2 | 2 | 0 |

Most missing delivery dates are **expected**: orders that are shipped, canceled, unavailable, invoiced, processing, created or approved have not reached the customer. Only 8 delivered orders lack a customer delivery date; these are data problems. Six canceled orders do have a customer delivery date, which is unusual and will be reviewed during cleaning.

### raw_order_items

| Column | Description |
|---|---|
| `order_id` | Links to `raw_orders` |
| `order_item_id` | Item number within the order (1, 2, 3 ...) |
| `product_id` | Links to `raw_products` |
| `seller_id` | Links to `raw_sellers` |
| `shipping_limit_date` | Deadline for the seller to hand the item to the carrier |
| `price` | Item price (min 0.85, max 6,735.00, no zero or negative values) |
| `freight_value` | Freight charged for the item (max 409.68; 383 items have freight of 0) |

No missing values. 98,666 orders have at least one item. 88,863 orders have exactly one item and 9,803 have two or more (maximum 21).

### raw_order_payments

| Column | Description |
|---|---|
| `order_id` | Links to `raw_orders` |
| `payment_sequential` | Payment number within the order |
| `payment_type` | credit_card (76,795), boleto (19,784), voucher (5,775), debit_card (1,529), not_defined (3) |
| `payment_installments` | Number of instalments (0 to 24; 2 rows have 0) |
| `payment_value` | Amount of this payment record (max 13,664.08; 9 rows are 0) |

No missing values. 96,479 orders have one payment record and 2,961 have two or more (maximum 29). Several records per order usually mean the customer combined payment methods, for example vouchers plus a card.

### raw_order_reviews

| Column | Description | Missing |
|---|---|---|
| `review_id` | Review identifier | 0 |
| `order_id` | Links to `raw_orders` | 0 |
| `review_score` | 1 to 5 stars | 0 |
| `review_comment_title` | Optional title | 87,658 (88.3%) |
| `review_comment_message` | Optional comment | 58,256 (58.7%) |
| `review_creation_date` | When the review survey was sent (usually midnight; 85 rows include a time) | 0 |
| `review_answer_timestamp` | When the customer answered | 0 |

`review_id` alone is **not** unique: 789 review ids are linked to two or three different orders. The combination `review_id` + `order_id` is unique. From the order side, 98,126 orders have one review, 543 have two and 4 have three. A rule for choosing one review per order will be set in the modelling stage.

Score distribution: 5 stars 57,328; 4 stars 19,142; 3 stars 8,179; 2 stars 3,151; 1 star 11,424.

### raw_customers

| Column | Description |
|---|---|
| `customer_id` | Customer key **for one order**. A new `customer_id` is created for every order. |
| `customer_unique_id` | Identifies the actual person across orders |
| `customer_zip_code_prefix` | First 5 digits of the zip code |
| `customer_city` | City |
| `customer_state` | State (27 distinct values) |

There are 99,441 `customer_id` values but only 96,096 `customer_unique_id` values. 93,099 people appear with one customer id and 2,997 appear with two or more (maximum 17).

**Why this matters:** counting distinct `customer_id` would make every order look like a new customer, and repeat purchasing would appear to be zero. Repeat-customer analysis must use `customer_unique_id`.

### raw_products

| Column | Description | Missing |
|---|---|---|
| `product_id` | Product identifier | 0 |
| `product_category_name` | Category in Portuguese | 610 |
| `product_name_lenght` | Length of product name (misspelled in source) | 610 |
| `product_description_lenght` | Length of description (misspelled in source) | 610 |
| `product_photos_qty` | Number of photos | 610 |
| `product_weight_g`, `product_length_cm`, `product_height_cm`, `product_width_cm` | Package size and weight | 2 each |

### raw_sellers

`seller_id`, `seller_zip_code_prefix`, `seller_city`, `seller_state`. No missing values. Used only where seller information helps explain delivery performance.

### raw_category_translation

`product_category_name` (Portuguese) and `product_category_name_english`. 71 categories. The file starts with a byte order mark, so it is read with `utf-8-sig` encoding.

## Date coverage

| Column | First | Last |
|---|---|---|
| `order_purchase_timestamp` | 2016-09-04 21:15:19 | 2018-10-17 17:30:18 |
| `order_delivered_customer_date` | 2016-10-11 13:46:32 | 2018-10-17 13:22:46 |
| `order_estimated_delivery_date` | 2016-09-30 | 2018-11-12 |
| `review_creation_date` | 2016-10-02 | 2018-08-31 |

These are the raw minimum and maximum values before any cleaning.

Orders per purchase month are thin at both ends: 2016-09 has 4 orders, 2016-10 has 324, 2016-11 has none, 2016-12 has 1, while 2018-09 has 16 and 2018-10 has 4. From 2017-01 to 2018-08 every month has between 800 and 7,544 orders. The boundary months will be treated as incomplete when calculating trends and growth.

## Timestamp sequence issues

| Check | Orders |
|---|---|
| Approved before purchase | 0 |
| Handed to carrier before purchase | 166 |
| Delivered to customer before purchase | 0 |
| Delivered to customer before handed to carrier | 23 |

These will be flagged during cleaning rather than silently deleted.

## Join risks: why raw joins can inflate totals

`raw_order_items`, `raw_order_payments` and `raw_order_reviews` all have **many rows per order**. If two of them are joined directly on `order_id`, every item row is repeated for every payment row of the same order. An order with 2 items and 3 payments becomes 6 rows.

Measured on this dataset (query `join_inflation_example`):

| Measure | Correct total | Total after joining items to payments | Change |
|---|---|---|---|
| Sum of item price | 13,591,643.70 | 14,209,115.34 | +4.5% |
| Sum of payment value | 16,008,872.12 | 20,308,134.71 | +26.9% |

The joined result has 117,601 rows instead of 112,650 items or 103,886 payments.

**Rule for this project:** aggregate items, payments and reviews to one row per order *before* joining them to the orders table. Validation queries will compare totals before and after every join.

Note also that item price plus freight and payment value measure different things (payment records may include vouchers or instalment charges, and one order has no payment record); the size of the difference will be investigated in the analysis stage. They are kept as separate measures and not forced to match.

## Reporting models

The analysis queries are built on five reporting models created by [`sql/models/`](../sql/models/). Items, payments and reviews are aggregated to one row per order **before** they are joined, so no join can multiply rows.

| Model | Grain (one row = ) | Rows | Main use |
|---|---|---|---|
| `model_order_items` | one order item | 112,650 | Category and seller analysis |
| `model_orders` | one order | 99,441 | Sales, order value, delivery, reviews |
| `model_customers` | one person (`customer_unique_id`) | 96,096 | Repeat purchasing |
| `model_monthly_sales` | one purchase month | 25 | Trends and growth |
| `model_delivery_performance` | one customer state | 27 | Delivery comparison by state |

Key rules in `model_orders`:

- `merchandise_value` = sum of item prices; `freight_value` and `payment_value` are separate columns.
- **Multiple reviews per order:** 547 orders have 2 or 3 reviews, and in 202 of them the scores differ. The review with the latest `review_answer_ts` is kept (the customer's most recent opinion). No order has two reviews answered at the same time, so the choice is unique. `review_count` keeps the original number.
- `delivery_days` = purchase to customer delivery, in days. `is_late` = 1 when the delivery **date** is after the estimated delivery **date**. These columns are filled only when `is_valid_delivery = 1`.
- `customer_state` in `model_customers` comes from the person's first order (39 people ordered from more than one state).

The models are checked by 41 validation queries in [`sql/validation/`](../sql/validation/) (key uniqueness, required fields, referential integrity, row counts and money totals before and after joins, timestamp order). The results are in [`reports/tables/validation/validation_summary.csv`](../reports/tables/validation/validation_summary.csv). `run_project.py` stops if any check fails.
