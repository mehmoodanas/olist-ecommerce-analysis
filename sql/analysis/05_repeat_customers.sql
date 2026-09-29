-- Repeat purchasing by person (customer_unique_id), delivered orders only.
--
-- This is repeat purchasing WITHIN the observed data (2016-09 to 2018-08), not
-- lifetime retention. Customers who first bought late in the period had less
-- time to buy again, so a fixed 180-day window is also reported for customers
-- who could be followed for at least 180 days.


-- name: repeat_customer_rate
SELECT
    COUNT(*)                                    AS customers_with_delivered_order,
    SUM(is_repeat_customer)                     AS repeat_customers,
    ROUND(100.0 * SUM(is_repeat_customer) / COUNT(*), 2) AS repeat_rate_pct,
    SUM(days_to_second_order = 0)               AS second_order_same_day,
    SUM(days_to_second_order > 0)               AS second_order_later_day,
    ROUND(100.0 * SUM(days_to_second_order > 0) / COUNT(*), 2) AS repeat_rate_excl_same_day_pct
FROM model_customers
WHERE delivered_orders >= 1;


-- name: orders_per_customer
SELECT
    CASE WHEN delivered_orders >= 4 THEN '4+' ELSE CAST(delivered_orders AS TEXT) END AS delivered_orders,
    COUNT(*) AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
FROM model_customers
WHERE delivered_orders >= 1
GROUP BY 1
ORDER BY 1;


-- name: repeat_within_180_days
-- Fair comparison: only customers whose first delivered order was at least
-- 180 days before the end of follow-up (observed_days >= 180).
SELECT
    COUNT(*)                                                   AS eligible_customers,
    SUM(days_to_second_order BETWEEN 1 AND 180)                AS returned_within_180_days,
    ROUND(100.0 * SUM(days_to_second_order BETWEEN 1 AND 180) / COUNT(*), 2) AS pct_returned_within_180_days
FROM model_customers
WHERE delivered_orders >= 1
  AND observed_days >= 180;


-- name: repeat_rate_by_first_purchase_quarter
-- Shows how the observed repeat rate depends on follow-up time.
-- Quarters with fewer than 1,000 first-time customers are excluded.
SELECT
    substr(first_delivered_purchase_ts, 1, 4) || '-Q' ||
        ((CAST(substr(first_delivered_purchase_ts, 6, 2) AS INTEGER) + 2) / 3) AS first_purchase_quarter,
    COUNT(*)                                            AS new_customers,
    ROUND(AVG(observed_days))                           AS avg_follow_up_days,
    ROUND(100.0 * SUM(days_to_second_order > 0) / COUNT(*), 2) AS pct_returned_later_day
FROM model_customers
WHERE delivered_orders >= 1
GROUP BY first_purchase_quarter
HAVING COUNT(*) >= 1000
ORDER BY first_purchase_quarter;


-- name: repeat_vs_one_time_value
-- Average first-order value is compared so repeat customers are not credited
-- with value that simply comes from having more orders.
-- ROW_NUMBER picks exactly one first order per person, even if two orders
-- share the same purchase timestamp.
WITH first_orders AS (
    SELECT customer_unique_id, merchandise_value,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                              ORDER BY purchase_ts, order_id) AS rn
    FROM model_orders
    WHERE status_group = 'delivered'
)
SELECT
    CASE WHEN c.is_repeat_customer = 1 THEN 'repeat' ELSE 'one-time' END AS customer_type,
    COUNT(*)                                          AS customers,
    ROUND(AVG(f.merchandise_value), 2)                AS avg_first_order_value,
    ROUND(AVG(c.delivered_merchandise_value), 2)      AS avg_total_value
FROM model_customers AS c
JOIN first_orders AS f
  ON f.customer_unique_id = c.customer_unique_id AND f.rn = 1
GROUP BY customer_type;
