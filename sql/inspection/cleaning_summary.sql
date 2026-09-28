-- Summary of the cleaning step. src/run_project.py saves each result to
-- reports/tables/cleaning/<name>.csv. The numbers are used in reports/data_quality.md.


-- name: row_counts_raw_vs_clean
-- Cleaning flags records but deletes nothing, so raw and clean counts must match.
SELECT 'orders' AS entity,
       (SELECT COUNT(*) FROM raw_orders) AS raw_rows,
       (SELECT COUNT(*) FROM clean_orders) AS clean_rows
UNION ALL SELECT 'order_items',
       (SELECT COUNT(*) FROM raw_order_items), (SELECT COUNT(*) FROM clean_order_items)
UNION ALL SELECT 'order_payments',
       (SELECT COUNT(*) FROM raw_order_payments), (SELECT COUNT(*) FROM clean_order_payments)
UNION ALL SELECT 'order_reviews',
       (SELECT COUNT(*) FROM raw_order_reviews), (SELECT COUNT(*) FROM clean_order_reviews)
UNION ALL SELECT 'customers',
       (SELECT COUNT(*) FROM raw_customers), (SELECT COUNT(*) FROM clean_customers)
UNION ALL SELECT 'products',
       (SELECT COUNT(*) FROM raw_products), (SELECT COUNT(*) FROM clean_products)
UNION ALL SELECT 'sellers',
       (SELECT COUNT(*) FROM raw_sellers), (SELECT COUNT(*) FROM clean_sellers);


-- name: status_groups
SELECT status_group,
       order_status,
       COUNT(*)               AS orders,
       SUM(has_items)         AS orders_with_items,
       SUM(delivered_ts IS NOT NULL) AS orders_with_delivery_date,
       SUM(is_valid_delivery) AS valid_for_delivery_metrics
FROM clean_orders
GROUP BY status_group, order_status
ORDER BY status_group, orders DESC;


-- name: order_flags
SELECT 'delivered status but no delivery date' AS flag, SUM(flag_delivered_missing_date) AS orders
FROM clean_orders
UNION ALL SELECT 'not delivered status but has delivery date', SUM(flag_not_delivered_but_has_date)
FROM clean_orders
UNION ALL SELECT 'missing approval timestamp', SUM(flag_missing_approval)
FROM clean_orders
UNION ALL SELECT 'handed to carrier before purchase', SUM(flag_carrier_before_purchase)
FROM clean_orders
UNION ALL SELECT 'delivered before handed to carrier', SUM(flag_delivered_before_carrier)
FROM clean_orders
UNION ALL SELECT 'no items', SUM(has_items = 0)
FROM clean_orders
UNION ALL SELECT 'no payment record', SUM(has_payment = 0)
FROM clean_orders
UNION ALL SELECT 'no review', SUM(has_review = 0)
FROM clean_orders;


-- name: missing_approval_by_status
SELECT order_status, COUNT(*) AS orders_missing_approval
FROM clean_orders
WHERE flag_missing_approval = 1
GROUP BY order_status
ORDER BY orders_missing_approval DESC;


-- name: carrier_before_purchase_gap
-- How far before the purchase the carrier date is, for flagged orders.
SELECT COUNT(*) AS orders,
       ROUND(AVG((julianday(purchase_ts) - julianday(carrier_ts)) * 24), 1) AS avg_hours_before,
       ROUND(MAX(julianday(purchase_ts) - julianday(carrier_ts)), 1)        AS max_days_before
FROM clean_orders
WHERE flag_carrier_before_purchase = 1;


-- name: item_and_payment_flags
SELECT 'order items with zero freight' AS flag, SUM(flag_zero_freight) AS rows_flagged
FROM clean_order_items
UNION ALL SELECT 'payments with zero value', SUM(flag_zero_value) FROM clean_order_payments
UNION ALL SELECT 'payments with zero instalments', SUM(flag_zero_installments) FROM clean_order_payments
UNION ALL SELECT 'payments with type not_defined', SUM(flag_type_not_defined) FROM clean_order_payments;


-- name: not_defined_payments_by_status
SELECT o.order_status, COUNT(*) AS payment_rows
FROM clean_order_payments AS p
JOIN clean_orders AS o ON o.order_id = p.order_id
WHERE p.flag_type_not_defined = 1
GROUP BY o.order_status;


-- name: category_rules
SELECT CASE
           WHEN flag_missing_category = 1 THEN 'no category -> unknown'
           WHEN flag_manual_translation = 1 THEN 'translated by hand'
           ELSE 'translated from file'
       END AS rule,
       COUNT(*) AS products,
       COUNT(DISTINCT category) AS categories
FROM clean_products
GROUP BY rule;


-- name: items_by_category_rule
SELECT CASE
           WHEN p.flag_missing_category = 1 THEN 'no category -> unknown'
           WHEN p.flag_manual_translation = 1 THEN 'translated by hand'
           ELSE 'translated from file'
       END AS rule,
       COUNT(*) AS order_items,
       ROUND(SUM(i.price), 2) AS item_price_total
FROM clean_order_items AS i
JOIN clean_products AS p ON p.product_id = i.product_id
GROUP BY rule;


-- name: price_distribution
-- Item prices are skewed; high values are kept (see data_quality.md).
WITH ranked AS (
    SELECT price,
           ROW_NUMBER() OVER (ORDER BY price) AS rn,
           COUNT(*) OVER () AS n
    FROM clean_order_items
)
SELECT
    MIN(price) AS min_price,
    MAX(CASE WHEN rn = CAST(0.25 * n AS INTEGER) THEN price END) AS p25,
    MAX(CASE WHEN rn = CAST(0.50 * n AS INTEGER) THEN price END) AS median,
    MAX(CASE WHEN rn = CAST(0.75 * n AS INTEGER) THEN price END) AS p75,
    MAX(CASE WHEN rn = CAST(0.99 * n AS INTEGER) THEN price END) AS p99,
    MAX(price) AS max_price,
    SUM(price > 1000) AS items_over_1000
FROM ranked;
