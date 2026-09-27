-- Raw data inspection queries.
-- Each query starts with a "-- name:" line. src/profile_raw.py runs them
-- and saves every result to reports/tables/inspection/<name>.csv.
-- These queries only read the raw_* tables; nothing is changed.


-- name: row_counts_and_keys
-- Row count per table and distinct values of the column(s) that should be the key.
-- If rows = distinct_key, the key is unique.
SELECT 'raw_orders' AS table_name, 'order_id' AS key_column,
       COUNT(*) AS rows, COUNT(DISTINCT order_id) AS distinct_key
FROM raw_orders
UNION ALL
SELECT 'raw_order_items', 'order_id + order_item_id',
       COUNT(*), COUNT(DISTINCT order_id || '-' || order_item_id)
FROM raw_order_items
UNION ALL
SELECT 'raw_order_payments', 'order_id + payment_sequential',
       COUNT(*), COUNT(DISTINCT order_id || '-' || payment_sequential)
FROM raw_order_payments
UNION ALL
SELECT 'raw_order_reviews', 'review_id', COUNT(*), COUNT(DISTINCT review_id)
FROM raw_order_reviews
UNION ALL
SELECT 'raw_order_reviews', 'review_id + order_id',
       COUNT(*), COUNT(DISTINCT review_id || '-' || order_id)
FROM raw_order_reviews
UNION ALL
SELECT 'raw_customers', 'customer_id', COUNT(*), COUNT(DISTINCT customer_id)
FROM raw_customers
UNION ALL
SELECT 'raw_customers', 'customer_unique_id', COUNT(*), COUNT(DISTINCT customer_unique_id)
FROM raw_customers
UNION ALL
SELECT 'raw_products', 'product_id', COUNT(*), COUNT(DISTINCT product_id)
FROM raw_products
UNION ALL
SELECT 'raw_sellers', 'seller_id', COUNT(*), COUNT(DISTINCT seller_id)
FROM raw_sellers
UNION ALL
SELECT 'raw_category_translation', 'product_category_name',
       COUNT(*), COUNT(DISTINCT product_category_name)
FROM raw_category_translation;


-- name: referential_integrity
-- Rows whose foreign key has no match in the parent table (0 = no orphans),
-- plus orders that have no child rows at all.
-- NOT IN (subquery) is used because the raw tables have no indexes.
SELECT 'order_items without order' AS check_name,
       COUNT(*) AS rows_failing
FROM raw_order_items WHERE order_id NOT IN (SELECT order_id FROM raw_orders)
UNION ALL
SELECT 'order_items without product', COUNT(*)
FROM raw_order_items WHERE product_id NOT IN (SELECT product_id FROM raw_products)
UNION ALL
SELECT 'order_items without seller', COUNT(*)
FROM raw_order_items WHERE seller_id NOT IN (SELECT seller_id FROM raw_sellers)
UNION ALL
SELECT 'payments without order', COUNT(*)
FROM raw_order_payments WHERE order_id NOT IN (SELECT order_id FROM raw_orders)
UNION ALL
SELECT 'reviews without order', COUNT(*)
FROM raw_order_reviews WHERE order_id NOT IN (SELECT order_id FROM raw_orders)
UNION ALL
SELECT 'orders without customer', COUNT(*)
FROM raw_orders WHERE customer_id NOT IN (SELECT customer_id FROM raw_customers)
UNION ALL
SELECT 'orders with no items', COUNT(*)
FROM raw_orders WHERE order_id NOT IN (SELECT order_id FROM raw_order_items)
UNION ALL
SELECT 'orders with no payment', COUNT(*)
FROM raw_orders WHERE order_id NOT IN (SELECT order_id FROM raw_order_payments)
UNION ALL
SELECT 'orders with no review', COUNT(*)
FROM raw_orders WHERE order_id NOT IN (SELECT order_id FROM raw_order_reviews)
UNION ALL
SELECT 'products with category missing from translation', COUNT(*)
FROM raw_products
WHERE product_category_name IS NOT NULL
  AND product_category_name NOT IN (SELECT product_category_name FROM raw_category_translation);


-- name: items_per_order
-- How many orders have 1, 2, 3 ... items. Orders with more than one item
-- are why item-level tables must be aggregated before joining to orders.
SELECT items_in_order, COUNT(*) AS orders
FROM (SELECT order_id, COUNT(*) AS items_in_order FROM raw_order_items GROUP BY order_id)
GROUP BY items_in_order
ORDER BY items_in_order;


-- name: payments_per_order
SELECT payment_rows, COUNT(*) AS orders
FROM (SELECT order_id, COUNT(*) AS payment_rows FROM raw_order_payments GROUP BY order_id)
GROUP BY payment_rows
ORDER BY payment_rows;


-- name: reviews_per_order
SELECT review_rows, COUNT(*) AS orders
FROM (SELECT order_id, COUNT(*) AS review_rows FROM raw_order_reviews GROUP BY order_id)
GROUP BY review_rows
ORDER BY review_rows;


-- name: orders_per_review_id
-- Some review_id values are linked to more than one order.
SELECT orders_linked, COUNT(*) AS review_ids
FROM (SELECT review_id, COUNT(*) AS orders_linked FROM raw_order_reviews GROUP BY review_id)
GROUP BY orders_linked
ORDER BY orders_linked;


-- name: customer_ids_per_unique_customer
-- customer_id is created per order; customer_unique_id identifies the person.
SELECT customer_ids, COUNT(*) AS unique_customers
FROM (SELECT customer_unique_id, COUNT(*) AS customer_ids
      FROM raw_customers GROUP BY customer_unique_id)
GROUP BY customer_ids
ORDER BY customer_ids;


-- name: order_status_and_missing_dates
-- Missing timestamps by order status. Missing delivery dates are expected
-- for orders that were never delivered (shipped, canceled, invoiced ...).
SELECT order_status,
       COUNT(*) AS orders,
       SUM(order_approved_at IS NULL) AS missing_approved,
       SUM(order_delivered_carrier_date IS NULL) AS missing_carrier_date,
       SUM(order_delivered_customer_date IS NULL) AS missing_customer_delivery,
       SUM(order_estimated_delivery_date IS NULL) AS missing_estimate,
       SUM(order_id NOT IN (SELECT order_id FROM raw_order_items)) AS orders_without_items
FROM raw_orders
GROUP BY order_status
ORDER BY orders DESC;


-- name: orders_per_month
-- Order volume by purchase month; shows thin boundary months.
SELECT substr(order_purchase_timestamp, 1, 7) AS purchase_month,
       COUNT(*) AS orders
FROM raw_orders
GROUP BY purchase_month
ORDER BY purchase_month;


-- name: date_coverage
SELECT 'order_purchase_timestamp' AS column_name,
       MIN(order_purchase_timestamp) AS min_value, MAX(order_purchase_timestamp) AS max_value
FROM raw_orders
UNION ALL
SELECT 'order_delivered_customer_date',
       MIN(order_delivered_customer_date), MAX(order_delivered_customer_date)
FROM raw_orders
UNION ALL
SELECT 'order_estimated_delivery_date',
       MIN(order_estimated_delivery_date), MAX(order_estimated_delivery_date)
FROM raw_orders
UNION ALL
SELECT 'review_creation_date', MIN(review_creation_date), MAX(review_creation_date)
FROM raw_order_reviews;


-- name: timestamp_sequence_issues
-- Events that happen before an earlier step in the order process.
-- Text comparison works because timestamps are stored as 'YYYY-MM-DD HH:MM:SS'.
SELECT 'approved before purchase' AS check_name,
       SUM(order_approved_at < order_purchase_timestamp) AS orders
FROM raw_orders
UNION ALL
SELECT 'handed to carrier before purchase',
       SUM(order_delivered_carrier_date < order_purchase_timestamp)
FROM raw_orders
UNION ALL
SELECT 'delivered to customer before purchase',
       SUM(order_delivered_customer_date < order_purchase_timestamp)
FROM raw_orders
UNION ALL
SELECT 'delivered to customer before handed to carrier',
       SUM(order_delivered_customer_date < order_delivered_carrier_date)
FROM raw_orders;


-- name: value_ranges
SELECT 'order_items.price' AS measure,
       MIN(CAST(price AS REAL)) AS min_value, MAX(CAST(price AS REAL)) AS max_value,
       SUM(CAST(price AS REAL) <= 0) AS zero_or_negative
FROM raw_order_items
UNION ALL
SELECT 'order_items.freight_value',
       MIN(CAST(freight_value AS REAL)), MAX(CAST(freight_value AS REAL)),
       SUM(CAST(freight_value AS REAL) <= 0)
FROM raw_order_items
UNION ALL
SELECT 'order_payments.payment_value',
       MIN(CAST(payment_value AS REAL)), MAX(CAST(payment_value AS REAL)),
       SUM(CAST(payment_value AS REAL) <= 0)
FROM raw_order_payments
UNION ALL
SELECT 'order_payments.payment_installments',
       MIN(CAST(payment_installments AS INTEGER)), MAX(CAST(payment_installments AS INTEGER)),
       SUM(CAST(payment_installments AS INTEGER) <= 0)
FROM raw_order_payments
UNION ALL
SELECT 'order_reviews.review_score',
       MIN(CAST(review_score AS INTEGER)), MAX(CAST(review_score AS INTEGER)),
       SUM(CAST(review_score AS INTEGER) NOT BETWEEN 1 AND 5)
FROM raw_order_reviews;


-- name: join_inflation_example
-- Joining two one-to-many tables (items and payments) on order_id repeats rows:
-- an order with 2 items and 3 payments becomes 6 rows. Totals then grow.
SELECT 'item price' AS measure,
       (SELECT ROUND(SUM(CAST(price AS REAL)), 2) FROM raw_order_items) AS correct_total,
       ROUND(SUM(CAST(i.price AS REAL)), 2) AS total_after_join,
       COUNT(*) AS rows_after_join
FROM raw_order_items AS i
JOIN raw_order_payments AS p ON p.order_id = i.order_id
UNION ALL
SELECT 'payment value',
       (SELECT ROUND(SUM(CAST(payment_value AS REAL)), 2) FROM raw_order_payments),
       ROUND(SUM(CAST(p.payment_value AS REAL)), 2),
       COUNT(*)
FROM raw_order_items AS i
JOIN raw_order_payments AS p ON p.order_id = i.order_id;


-- name: payment_types
SELECT payment_type, COUNT(*) AS payment_rows
FROM raw_order_payments
GROUP BY payment_type
ORDER BY payment_rows DESC;
