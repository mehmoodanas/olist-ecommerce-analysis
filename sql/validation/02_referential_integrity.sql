-- Validation: referential integrity between clean tables and reporting models.
-- Each check counts orphan rows (a child whose parent does not exist). Expected 0.


-- name: referential_integrity
SELECT 'clean_order_items -> clean_orders' AS check_name, 0 AS expected,
       COUNT(*) AS actual
FROM clean_order_items AS i
LEFT JOIN clean_orders AS o ON o.order_id = i.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'clean_order_items -> clean_products', 0, COUNT(*)
FROM clean_order_items AS i
LEFT JOIN clean_products AS p ON p.product_id = i.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'clean_order_items -> clean_sellers', 0, COUNT(*)
FROM clean_order_items AS i
LEFT JOIN clean_sellers AS s ON s.seller_id = i.seller_id
WHERE s.seller_id IS NULL
UNION ALL
SELECT 'clean_order_payments -> clean_orders', 0, COUNT(*)
FROM clean_order_payments AS p
LEFT JOIN clean_orders AS o ON o.order_id = p.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'clean_order_reviews -> clean_orders', 0, COUNT(*)
FROM clean_order_reviews AS r
LEFT JOIN clean_orders AS o ON o.order_id = r.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'clean_orders -> clean_customers', 0, COUNT(*)
FROM clean_orders AS o
LEFT JOIN clean_customers AS c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'model_order_items -> model_orders', 0, COUNT(*)
FROM model_order_items AS i
LEFT JOIN model_orders AS o ON o.order_id = i.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'model_orders -> model_customers', 0, COUNT(*)
FROM model_orders AS o
LEFT JOIN model_customers AS c ON c.customer_unique_id = o.customer_unique_id
WHERE c.customer_unique_id IS NULL
-- the chosen review must belong to the same order
UNION ALL
SELECT 'model_orders chosen review -> clean_order_reviews', 0, COUNT(*)
FROM model_orders AS o
LEFT JOIN clean_order_reviews AS r
       ON r.review_id = o.review_id AND r.order_id = o.order_id
WHERE o.review_id IS NOT NULL AND r.review_id IS NULL;
