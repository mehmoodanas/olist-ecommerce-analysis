-- Validation: joins must not add or lose rows, and totals must be the same
-- before and after aggregation and joining. A difference here would mean a
-- join multiplied rows (see join risks in docs/data_dictionary.md).
-- Money totals are rounded to 2 decimals; run_project.py allows a 0.01
-- difference for floating-point rounding.


-- name: join_row_counts
SELECT 'model_orders rows = clean_orders rows' AS check_name,
       (SELECT COUNT(*) FROM clean_orders) AS expected,
       (SELECT COUNT(*) FROM model_orders) AS actual
UNION ALL
SELECT 'model_order_items rows = clean_order_items rows',
       (SELECT COUNT(*) FROM clean_order_items),
       (SELECT COUNT(*) FROM model_order_items)
UNION ALL
SELECT 'model_customers rows = distinct customer_unique_id',
       (SELECT COUNT(DISTINCT customer_unique_id) FROM clean_customers),
       (SELECT COUNT(*) FROM model_customers)
UNION ALL
SELECT 'orders with a chosen review = orders with any review',
       (SELECT COUNT(DISTINCT order_id) FROM clean_order_reviews),
       (SELECT COUNT(review_id) FROM model_orders)
UNION ALL
SELECT 'sum of review_count = review rows',
       (SELECT COUNT(*) FROM clean_order_reviews),
       (SELECT SUM(review_count) FROM model_orders)
UNION ALL
SELECT 'sum of item_count = item rows',
       (SELECT COUNT(*) FROM clean_order_items),
       (SELECT SUM(item_count) FROM model_orders)
UNION ALL
SELECT 'sum of payment_count = payment rows',
       (SELECT COUNT(*) FROM clean_order_payments),
       (SELECT SUM(payment_count) FROM model_orders);


-- name: join_totals
SELECT 'item price: clean_order_items vs model_orders' AS check_name,
       (SELECT ROUND(SUM(price), 2) FROM clean_order_items) AS expected,
       (SELECT ROUND(SUM(merchandise_value), 2) FROM model_orders) AS actual
UNION ALL
SELECT 'item price: clean_order_items vs model_order_items',
       (SELECT ROUND(SUM(price), 2) FROM clean_order_items),
       (SELECT ROUND(SUM(price), 2) FROM model_order_items)
UNION ALL
SELECT 'freight: clean_order_items vs model_orders',
       (SELECT ROUND(SUM(freight_value), 2) FROM clean_order_items),
       (SELECT ROUND(SUM(freight_value), 2) FROM model_orders)
UNION ALL
SELECT 'payment value: clean_order_payments vs model_orders',
       (SELECT ROUND(SUM(payment_value), 2) FROM clean_order_payments),
       (SELECT ROUND(SUM(payment_value), 2) FROM model_orders)
UNION ALL
SELECT 'delivered merchandise: model_orders vs model_monthly_sales',
       (SELECT ROUND(SUM(merchandise_value), 2) FROM model_orders WHERE status_group = 'delivered'),
       (SELECT ROUND(SUM(merchandise_value), 2) FROM model_monthly_sales)
UNION ALL
SELECT 'delivered merchandise: model_orders vs model_customers',
       (SELECT ROUND(SUM(merchandise_value), 2) FROM model_orders WHERE status_group = 'delivered'),
       (SELECT ROUND(SUM(delivered_merchandise_value), 2) FROM model_customers)
UNION ALL
SELECT 'delivered orders: model_orders vs model_monthly_sales',
       (SELECT COUNT(*) FROM model_orders WHERE status_group = 'delivered'),
       (SELECT SUM(delivered_orders) FROM model_monthly_sales)
UNION ALL
SELECT 'delivered orders: model_orders vs model_customers',
       (SELECT COUNT(*) FROM model_orders WHERE status_group = 'delivered'),
       (SELECT SUM(delivered_orders) FROM model_customers)
UNION ALL
SELECT 'valid deliveries: model_orders vs model_delivery_performance',
       (SELECT SUM(is_valid_delivery) FROM model_orders),
       (SELECT SUM(valid_deliveries) FROM model_delivery_performance);
