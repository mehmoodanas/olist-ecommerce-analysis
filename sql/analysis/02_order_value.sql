-- Average order value (AOV) and how payment value compares with merchandise value.
--
-- AOV = merchandise value / delivered orders. Order values are skewed, so the
-- median is reported next to the mean.


-- name: aov_summary
WITH ranked AS (
    SELECT merchandise_value,
           item_count,
           ROW_NUMBER() OVER (ORDER BY merchandise_value) AS rn,
           COUNT(*) OVER ()                               AS n
    FROM model_orders
    WHERE status_group = 'delivered'
)
SELECT
    MAX(n)                                          AS delivered_orders,
    ROUND(SUM(merchandise_value) / COUNT(*), 2)     AS mean_order_value,
    MAX(CASE WHEN rn = (n + 1) / 2 THEN merchandise_value END) AS median_order_value,
    ROUND(AVG(item_count), 3)                       AS avg_items_per_order,
    ROUND(100.0 * SUM(item_count > 1) / COUNT(*), 2) AS pct_orders_multi_item
FROM ranked;


-- name: order_value_bands
-- How delivered orders and sales are spread across order-value bands.
SELECT
    CASE
        WHEN merchandise_value < 50   THEN '1: under 50'
        WHEN merchandise_value < 100  THEN '2: 50-99'
        WHEN merchandise_value < 200  THEN '3: 100-199'
        WHEN merchandise_value < 500  THEN '4: 200-499'
        WHEN merchandise_value < 1000 THEN '5: 500-999'
        ELSE '6: 1000 and over'
    END AS order_value_band,
    COUNT(*) AS delivered_orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                           AS pct_of_orders,
    ROUND(SUM(merchandise_value), 2)                                             AS merchandise_value,
    ROUND(100.0 * SUM(merchandise_value) / SUM(SUM(merchandise_value)) OVER (), 2) AS pct_of_sales
FROM model_orders
WHERE status_group = 'delivered'
GROUP BY order_value_band
ORDER BY order_value_band;


-- name: payment_vs_merchandise
-- Payment value is expected to equal merchandise + freight. Differences above
-- 0.01 are counted by main payment type. Credit-card orders paid in several
-- instalments can include extra charges, which would make payment higher.
-- The 1 delivered order with no payment record is excluded here.
SELECT
    main_payment_type,
    (max_installments > 1)                                         AS paid_in_instalments,
    COUNT(*)                                                       AS delivered_orders,
    SUM(ABS(payment_value - (merchandise_value + freight_value)) <= 0.01) AS orders_matching,
    SUM(payment_value - (merchandise_value + freight_value) > 0.01)  AS orders_paid_more,
    SUM(payment_value - (merchandise_value + freight_value) < -0.01) AS orders_paid_less,
    ROUND(SUM(payment_value - (merchandise_value + freight_value)), 2) AS net_difference
FROM model_orders
WHERE status_group = 'delivered' AND payment_value IS NOT NULL
GROUP BY main_payment_type, paid_in_instalments
ORDER BY delivered_orders DESC;
