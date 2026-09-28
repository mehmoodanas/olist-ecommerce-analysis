-- Clean orders: one row per order.
--
-- Rules (see reports/data_quality.md):
-- * Timestamps are stored by SQLite as text 'YYYY-MM-DD HH:MM:SS'. datetime() is
--   applied so any value that is not a valid timestamp becomes NULL (none found).
-- * The estimated delivery date never has a time part, so it is kept as a date.
-- * Orders are grouped by status:
--     delivered      -> 'delivered'
--     shipped, invoiced, processing, approved, created -> 'in_progress'
--     canceled, unavailable -> 'not_fulfilled'
-- * No order is deleted. Unusual records are flagged (flag_* = 1) so later steps
--   can decide whether to include them.
-- * A missing customer delivery date is only a data problem when the status is
--   'delivered'. For other statuses the order simply never arrived.

DROP TABLE IF EXISTS clean_orders;

CREATE TABLE clean_orders AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    CASE
        WHEN o.order_status = 'delivered' THEN 'delivered'
        WHEN o.order_status IN ('canceled', 'unavailable') THEN 'not_fulfilled'
        ELSE 'in_progress'
    END AS status_group,

    datetime(o.order_purchase_timestamp)       AS purchase_ts,
    datetime(o.order_approved_at)              AS approved_ts,
    datetime(o.order_delivered_carrier_date)   AS carrier_ts,
    datetime(o.order_delivered_customer_date)  AS delivered_ts,
    date(o.order_estimated_delivery_date)      AS estimated_delivery_date,
    date(o.order_purchase_timestamp)           AS purchase_date,
    strftime('%Y-%m', o.order_purchase_timestamp) AS purchase_month,

    -- does the order have child rows?
    (o.order_id IN (SELECT order_id FROM raw_order_items))    AS has_items,
    (o.order_id IN (SELECT order_id FROM raw_order_payments)) AS has_payment,
    (o.order_id IN (SELECT order_id FROM raw_order_reviews))  AS has_review,

    -- data quality flags
    (o.order_status = 'delivered' AND o.order_delivered_customer_date IS NULL)
        AS flag_delivered_missing_date,
    (o.order_status <> 'delivered' AND o.order_delivered_customer_date IS NOT NULL)
        AS flag_not_delivered_but_has_date,
    (o.order_approved_at IS NULL) AS flag_missing_approval,
    -- comparisons with a NULL date return NULL, so COALESCE turns them into 0
    COALESCE(o.order_delivered_carrier_date < o.order_purchase_timestamp, 0)
        AS flag_carrier_before_purchase,
    COALESCE(o.order_delivered_customer_date < o.order_delivered_carrier_date, 0)
        AS flag_delivered_before_carrier,

    -- usable for delivery time and late-delivery metrics:
    -- delivered status, a delivery date exists and it is not before the purchase
    COALESCE(o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_delivered_customer_date >= o.order_purchase_timestamp, 0)
        AS is_valid_delivery
FROM raw_orders AS o;
