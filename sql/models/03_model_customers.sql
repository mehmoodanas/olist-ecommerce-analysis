-- Customer summary: one row per person (customer_unique_id).
--
-- customer_id is created for every order, so it cannot identify repeat buyers.
-- This model groups orders by customer_unique_id instead.
--
-- Rules:
-- * Purchase counts and values use delivered orders only (same basis as sales
--   metrics). total_orders keeps all statuses for reference.
-- * customer_state is taken from the person's FIRST order. 39 people ordered
--   from more than one state; using the first order gives each person one state.
-- * is_repeat_customer = 1 when the person has 2 or more delivered orders.
--   This is repeat purchasing WITHIN the observed data only. People who first
--   bought near the end of the data had little time to buy again, so
--   observed_days is kept to show how long each person could be followed.
-- * days_to_second_order is 0 when the second order was placed on the same day
--   (for example, a basket split into two orders). The analysis reports these
--   separately because they are not a "return" in the usual sense.

DROP TABLE IF EXISTS model_customers;

CREATE TABLE model_customers AS
WITH orders_numbered AS (
    SELECT customer_unique_id,
           order_id,
           purchase_ts,
           customer_state,
           status_group,
           merchandise_value,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                              ORDER BY purchase_ts, order_id) AS order_number_all,
           CASE WHEN status_group = 'delivered'
                THEN ROW_NUMBER() OVER (PARTITION BY customer_unique_id, status_group
                                        ORDER BY purchase_ts, order_id) END AS delivered_order_number
    FROM model_orders
),
data_end AS (
    SELECT MAX(purchase_ts) AS last_purchase_in_data FROM model_orders
)
SELECT
    n.customer_unique_id,
    MAX(CASE WHEN n.order_number_all = 1 THEN n.customer_state END) AS customer_state,
    COUNT(*)                                                       AS total_orders,
    SUM(n.status_group = 'delivered')                              AS delivered_orders,
    ROUND(SUM(CASE WHEN n.status_group = 'delivered'
                   THEN n.merchandise_value ELSE 0 END), 2)       AS delivered_merchandise_value,
    MIN(CASE WHEN n.delivered_order_number = 1 THEN n.purchase_ts END) AS first_delivered_purchase_ts,
    MAX(CASE WHEN n.status_group = 'delivered' THEN n.purchase_ts END) AS last_delivered_purchase_ts,
    -- whole calendar days between the first and second delivered order
    CAST(julianday(date(MIN(CASE WHEN n.delivered_order_number = 2 THEN n.purchase_ts END)))
      - julianday(date(MIN(CASE WHEN n.delivered_order_number = 1 THEN n.purchase_ts END)))
      AS INTEGER)                                                  AS days_to_second_order,
    (SUM(n.status_group = 'delivered') >= 2)                       AS is_repeat_customer,
    julianday((SELECT last_purchase_in_data FROM data_end))
      - julianday(MIN(CASE WHEN n.delivered_order_number = 1 THEN n.purchase_ts END))
                                                                   AS observed_days
FROM orders_numbered AS n
GROUP BY n.customer_unique_id;
