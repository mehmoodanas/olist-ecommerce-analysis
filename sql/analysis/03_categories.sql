-- Category contribution to merchandise sales (delivered orders).
--
-- Notes:
-- * Sales value and item counts ADD UP across categories.
-- * Order counts do NOT add up: an order with items from two categories is
--   counted once in each. The sum of category orders is therefore larger than
--   the number of delivered orders (checked in category_order_overlap).
-- * 'unknown' = products with no category in the source; kept as its own group.


-- name: category_contribution
SELECT
    category,
    COUNT(*)                                   AS items_sold,
    COUNT(DISTINCT order_id)                   AS orders_containing_category,
    ROUND(SUM(price), 2)                       AS merchandise_value,
    ROUND(100.0 * SUM(price) / SUM(SUM(price)) OVER (), 2) AS pct_of_sales,
    ROUND(AVG(price), 2)                       AS avg_item_price,
    ROUND(SUM(freight_value) / SUM(price) * 100, 1) AS freight_pct_of_price
FROM model_order_items
WHERE status_group = 'delivered'
GROUP BY category
ORDER BY merchandise_value DESC;


-- name: top_category_concentration
-- How much of sales the largest categories account for together.
WITH ranked AS (
    SELECT category,
           SUM(price) AS merchandise_value,
           ROW_NUMBER() OVER (ORDER BY SUM(price) DESC) AS sales_rank
    FROM model_order_items
    WHERE status_group = 'delivered'
    GROUP BY category
)
SELECT
    COUNT(*)                                                             AS categories,
    ROUND(100.0 * SUM(CASE WHEN sales_rank <= 5  THEN merchandise_value END) / SUM(merchandise_value), 2) AS top5_pct,
    ROUND(100.0 * SUM(CASE WHEN sales_rank <= 10 THEN merchandise_value END) / SUM(merchandise_value), 2) AS top10_pct,
    ROUND(100.0 * SUM(CASE WHEN category = 'unknown' THEN merchandise_value END) / SUM(merchandise_value), 2) AS unknown_pct
FROM ranked;


-- name: category_order_overlap
-- Shows why category order counts cannot be summed.
SELECT
    (SELECT COUNT(*) FROM model_orders WHERE status_group = 'delivered') AS delivered_orders,
    SUM(categories_in_order)                                             AS sum_of_category_order_counts,
    SUM(categories_in_order > 1)                                         AS orders_with_2plus_categories
FROM (
    SELECT order_id, COUNT(DISTINCT category) AS categories_in_order
    FROM model_order_items
    WHERE status_group = 'delivered'
    GROUP BY order_id
);
