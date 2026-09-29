-- Item-level reporting model: one row per order item (order_id + order_item_id).
--
-- Adds the order, customer, product and seller attributes that item-level
-- questions need (category and state analysis). Every join below is
-- many-to-one, so the row count must stay equal to clean_order_items
-- (checked in sql/validation/).
--
-- Rules:
-- * All items are kept, whatever the order status. Use status_group = 'delivered'
--   for sales metrics (see docs/metric_definitions.md).
-- * item_value = price only. Freight is a separate column and is not merchandise sales.

DROP TABLE IF EXISTS model_order_items;

CREATE TABLE model_order_items AS
SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    o.order_status,
    o.status_group,
    o.purchase_ts,
    o.purchase_month,
    c.customer_unique_id,
    c.customer_state,
    p.category,
    p.flag_missing_category,
    s.seller_state,
    i.price,
    i.freight_value,
    i.flag_zero_freight
FROM clean_order_items AS i
JOIN clean_orders    AS o ON o.order_id    = i.order_id
JOIN clean_customers AS c ON c.customer_id = o.customer_id
JOIN clean_products  AS p ON p.product_id  = i.product_id
JOIN clean_sellers   AS s ON s.seller_id   = i.seller_id;
