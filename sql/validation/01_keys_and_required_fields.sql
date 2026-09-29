-- Validation: key uniqueness and required fields in the reporting models.
--
-- Every check returns one row: check_name, expected, actual.
-- run_project.py saves the results to reports/tables/validation/ and stops the
-- pipeline if actual differs from expected.


-- name: keys_and_required_fields
-- Key uniqueness: duplicated keys = total rows - distinct keys, expected 0.
SELECT 'model_orders: duplicate order_id' AS check_name, 0 AS expected,
       COUNT(*) - COUNT(DISTINCT order_id) AS actual
FROM model_orders
UNION ALL
SELECT 'model_order_items: duplicate order_id + order_item_id', 0,
       COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT order_id, order_item_id
                                         FROM model_order_items))
FROM model_order_items
UNION ALL
SELECT 'model_customers: duplicate customer_unique_id', 0,
       COUNT(*) - COUNT(DISTINCT customer_unique_id)
FROM model_customers
UNION ALL
SELECT 'model_monthly_sales: duplicate purchase_month', 0,
       COUNT(*) - COUNT(DISTINCT purchase_month)
FROM model_monthly_sales
UNION ALL
SELECT 'model_delivery_performance: duplicate customer_state', 0,
       COUNT(*) - COUNT(DISTINCT customer_state)
FROM model_delivery_performance

-- Required fields: these columns must never be NULL.
UNION ALL
SELECT 'model_orders: missing order_id, customer, state, status or purchase date', 0,
       SUM(order_id IS NULL OR customer_unique_id IS NULL OR customer_state IS NULL
           OR status_group IS NULL OR purchase_ts IS NULL OR purchase_month IS NULL)
FROM model_orders
UNION ALL
SELECT 'model_order_items: missing price, freight, category or seller state', 0,
       SUM(price IS NULL OR freight_value IS NULL OR category IS NULL OR seller_state IS NULL)
FROM model_order_items
UNION ALL
SELECT 'model_customers: missing customer_state', 0,
       SUM(customer_state IS NULL)
FROM model_customers
-- Every delivered order must have items, otherwise it adds an order with no sales.
UNION ALL
SELECT 'model_orders: delivered orders without items', 0,
       SUM(status_group = 'delivered' AND item_count = 0)
FROM model_orders
-- Delivery columns must be filled exactly when the delivery is valid.
UNION ALL
SELECT 'model_orders: delivery columns filled only for valid deliveries', 0,
       SUM((is_valid_delivery = 1) <> (delivery_days IS NOT NULL AND is_late IS NOT NULL
                                       AND days_vs_estimate IS NOT NULL))
FROM model_orders;
