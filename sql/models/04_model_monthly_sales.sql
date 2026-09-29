-- Monthly sales summary: one row per purchase month.
--
-- Rules:
-- * Sales columns use delivered orders only, dated by purchase month
--   (the month the customer placed the order).
-- * merchandise_value = sum of item prices. Freight and payment value are
--   separate columns and are never added into sales.
-- * all_orders counts every order placed in the month, whatever its status,
--   to show how many orders are left out.
-- * is_complete_month = 0 for the thin boundary months (2016-09 to 2016-12 and
--   2018-09 to 2018-10, see reports/data_quality.md). They stay in the table but
--   are excluded from growth comparisons. 2016-11 has no orders, so it has no row.

DROP TABLE IF EXISTS model_monthly_sales;

CREATE TABLE model_monthly_sales AS
SELECT
    purchase_month,
    COUNT(*)                                   AS all_orders,
    SUM(status_group = 'delivered')            AS delivered_orders,
    COUNT(DISTINCT CASE WHEN status_group = 'delivered'
                        THEN customer_unique_id END) AS delivered_customers,
    ROUND(SUM(CASE WHEN status_group = 'delivered'
                   THEN merchandise_value ELSE 0 END), 2) AS merchandise_value,
    ROUND(SUM(CASE WHEN status_group = 'delivered'
                   THEN freight_value ELSE 0 END), 2)     AS freight_value,
    ROUND(SUM(CASE WHEN status_group = 'delivered'
                   THEN COALESCE(payment_value, 0) ELSE 0 END), 2) AS payment_value,
    ROUND(SUM(CASE WHEN status_group = 'delivered' THEN merchandise_value ELSE 0 END)
          / NULLIF(SUM(status_group = 'delivered'), 0), 2) AS avg_order_value,
    (purchase_month BETWEEN '2017-01' AND '2018-08') AS is_complete_month
FROM model_orders
GROUP BY purchase_month
ORDER BY purchase_month;
