-- Delivery performance: delivery time and late deliveries.
--
-- Rules (docs/metric_definitions.md):
-- * Only orders with is_valid_delivery = 1.
-- * Delivery time = purchase timestamp to customer delivery timestamp, in days.
-- * Late = delivery DATE after the estimated delivery DATE.
-- * Rates for groups with fewer than 500 deliveries are not ranked.


-- name: delivery_overall
WITH ranked AS (
    SELECT delivery_days, days_vs_estimate, is_late,
           ROW_NUMBER() OVER (ORDER BY delivery_days) AS rn,
           COUNT(*) OVER ()                           AS n
    FROM model_orders
    WHERE is_valid_delivery = 1
)
SELECT
    MAX(n)                                        AS valid_deliveries,
    ROUND(AVG(delivery_days), 2)                  AS mean_delivery_days,
    ROUND(MAX(CASE WHEN rn = (n + 1) / 2 THEN delivery_days END), 2) AS median_delivery_days,
    SUM(is_late)                                  AS late_deliveries,
    ROUND(100.0 * SUM(is_late) / COUNT(*), 2)     AS late_rate_pct,
    ROUND(AVG(CASE WHEN is_late = 1 THEN days_vs_estimate END), 2) AS avg_days_late_when_late,
    SUM(days_vs_estimate = 0)                     AS delivered_on_estimated_day
FROM ranked;


-- name: late_rate_timestamp_vs_date
-- Why dates are compared: the estimate has no time part (00:00:00), so a
-- timestamp comparison counts deliveries later on the promised day as late.
SELECT
    SUM(date(delivered_ts) > estimated_delivery_date) AS late_by_date_rule,
    SUM(delivered_ts > estimated_delivery_date)       AS late_by_timestamp_rule,
    SUM(date(delivered_ts) = estimated_delivery_date) AS delivered_on_estimated_day
FROM model_orders
WHERE is_valid_delivery = 1;


-- name: late_by_state
-- All states are listed; meets_min_volume = 0 marks states with < 500 deliveries.
SELECT
    customer_state,
    valid_deliveries,
    avg_delivery_days,
    late_deliveries,
    late_rate_pct,
    avg_days_late_when_late,
    (valid_deliveries >= 500) AS meets_min_volume
FROM model_delivery_performance
ORDER BY meets_min_volume DESC, late_rate_pct DESC;


-- name: late_by_month
-- Late rate by purchase month (complete months only).
SELECT
    purchase_month,
    COUNT(*)                                  AS valid_deliveries,
    ROUND(AVG(delivery_days), 2)              AS avg_delivery_days,
    ROUND(100.0 * SUM(is_late) / COUNT(*), 2) AS late_rate_pct
FROM model_orders
WHERE is_valid_delivery = 1
  AND purchase_month BETWEEN '2017-01' AND '2018-08'
GROUP BY purchase_month
ORDER BY purchase_month;


-- name: late_by_seller_route
-- Segment: is the seller in the same state as the customer?
-- Only orders with a single seller, so each order has one seller state.
WITH order_seller AS (
    SELECT order_id, MAX(seller_state) AS seller_state
    FROM model_order_items
    GROUP BY order_id
)
SELECT
    CASE WHEN s.seller_state = o.customer_state THEN 'same state' ELSE 'different state' END AS seller_route,
    COUNT(*)                                    AS valid_deliveries,
    ROUND(AVG(o.delivery_days), 2)              AS avg_delivery_days,
    ROUND(100.0 * SUM(o.is_late) / COUNT(*), 2) AS late_rate_pct
FROM model_orders AS o
JOIN order_seller AS s ON s.order_id = o.order_id
WHERE o.is_valid_delivery = 1
  AND o.seller_count = 1
GROUP BY seller_route
ORDER BY seller_route;
