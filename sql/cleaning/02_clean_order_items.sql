-- Clean order items: one row per item line (order_id + order_item_id).
--
-- Rules:
-- * price and freight_value converted to REAL, order_item_id to INTEGER.
-- * All prices are above 0, so no item is removed.
-- * Freight of 0 is allowed (free shipping is plausible) but flagged.
-- * High prices are kept: they are real products, not errors
--   (maximum price is 6,735.00; see reports/data_quality.md).

DROP TABLE IF EXISTS clean_order_items;

CREATE TABLE clean_order_items AS
SELECT
    order_id,
    CAST(order_item_id AS INTEGER)   AS order_item_id,
    product_id,
    seller_id,
    datetime(shipping_limit_date)    AS shipping_limit_ts,
    CAST(price AS REAL)              AS price,
    CAST(freight_value AS REAL)      AS freight_value,
    (CAST(freight_value AS REAL) = 0) AS flag_zero_freight
FROM raw_order_items;
