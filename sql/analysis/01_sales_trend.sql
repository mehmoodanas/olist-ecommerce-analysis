-- Sales trend: monthly merchandise sales, order count and month-over-month growth.
--
-- Metric rules (docs/metric_definitions.md):
-- * Delivered orders only, dated by purchase month.
-- * Merchandise sales value = sum of item prices (not company revenue; freight separate).
-- * Growth is only calculated between complete months (2017-01 to 2018-08).
-- run_project.py saves each result to reports/tables/analysis/<name>.csv.


-- name: sales_overview
-- Headline totals for the whole period (delivered orders).
SELECT
    MIN(purchase_month)                         AS first_month,
    MAX(purchase_month)                         AS last_month,
    COUNT(*)                                    AS delivered_orders,
    COUNT(DISTINCT customer_unique_id)          AS customers,
    ROUND(SUM(merchandise_value), 2)            AS merchandise_value,
    ROUND(SUM(freight_value), 2)                AS freight_value,
    ROUND(SUM(payment_value), 2)                AS payment_value,
    ROUND(100.0 * SUM(freight_value) / SUM(merchandise_value), 2) AS freight_as_pct_of_merchandise
FROM model_orders
WHERE status_group = 'delivered';


-- name: monthly_sales
-- One row per month. Incomplete boundary months are kept but flagged.
SELECT
    purchase_month,
    is_complete_month,
    all_orders,
    delivered_orders,
    merchandise_value,
    freight_value,
    avg_order_value
FROM model_monthly_sales
ORDER BY purchase_month;


-- name: monthly_growth
-- Month-over-month growth with LAG(). Only complete months are included, so the
-- first complete month (2017-01) has no previous month and no growth value.
WITH complete AS (
    SELECT purchase_month, delivered_orders, merchandise_value
    FROM model_monthly_sales
    WHERE is_complete_month = 1
)
SELECT
    purchase_month,
    delivered_orders,
    merchandise_value,
    LAG(merchandise_value) OVER (ORDER BY purchase_month) AS prev_merchandise_value,
    ROUND(100.0 * (merchandise_value - LAG(merchandise_value) OVER (ORDER BY purchase_month))
          / LAG(merchandise_value) OVER (ORDER BY purchase_month), 1) AS sales_growth_pct,
    ROUND(100.0 * (delivered_orders - LAG(delivered_orders) OVER (ORDER BY purchase_month))
          / LAG(delivered_orders) OVER (ORDER BY purchase_month), 1)  AS orders_growth_pct
FROM complete
ORDER BY purchase_month;


-- name: year_on_year_jan_aug
-- 2017 has no complete months before January, so the fairest yearly comparison
-- is the same eight months (January to August) in both years.
SELECT
    substr(purchase_month, 1, 4)      AS year,
    SUM(delivered_orders)             AS delivered_orders,
    ROUND(SUM(merchandise_value), 2)  AS merchandise_value
FROM model_monthly_sales
WHERE substr(purchase_month, 6, 2) BETWEEN '01' AND '08'
  AND is_complete_month = 1
GROUP BY year
ORDER BY year;
