-- Customer-state performance (delivered orders, state of the customer's address).
--
-- Minimum volume: averages are shown for every state, but states with fewer than
-- 500 delivered orders are marked meets_min_volume = 0 and should not be ranked
-- on averages, because a few large orders can move them a lot.


-- name: state_performance
SELECT
    customer_state,
    COUNT(*)                                        AS delivered_orders,
    COUNT(DISTINCT customer_unique_id)              AS customers,
    ROUND(SUM(merchandise_value), 2)                AS merchandise_value,
    ROUND(100.0 * SUM(merchandise_value) / SUM(SUM(merchandise_value)) OVER (), 2) AS pct_of_sales,
    ROUND(AVG(merchandise_value), 2)                AS avg_order_value,
    ROUND(AVG(freight_value), 2)                    AS avg_freight_per_order,
    ROUND(100.0 * SUM(freight_value) / SUM(merchandise_value), 1) AS freight_pct_of_merchandise,
    (COUNT(*) >= 500)                               AS meets_min_volume
FROM model_orders
WHERE status_group = 'delivered'
GROUP BY customer_state
ORDER BY merchandise_value DESC;


-- name: state_concentration
-- Share of sales from the three largest states.
WITH s AS (
    SELECT customer_state, SUM(merchandise_value) AS merchandise_value,
           ROW_NUMBER() OVER (ORDER BY SUM(merchandise_value) DESC) AS sales_rank
    FROM model_orders
    WHERE status_group = 'delivered'
    GROUP BY customer_state
)
SELECT
    MAX(CASE WHEN sales_rank = 1 THEN customer_state END) || ', ' ||
    MAX(CASE WHEN sales_rank = 2 THEN customer_state END) || ', ' ||
    MAX(CASE WHEN sales_rank = 3 THEN customer_state END)           AS top3_states,
    ROUND(100.0 * SUM(CASE WHEN sales_rank <= 3 THEN merchandise_value END)
          / SUM(merchandise_value), 2)                              AS top3_pct_of_sales,
    ROUND(100.0 * SUM(CASE WHEN customer_state = 'SP' THEN merchandise_value END)
          / SUM(merchandise_value), 2)                              AS sp_pct_of_sales
FROM s;
