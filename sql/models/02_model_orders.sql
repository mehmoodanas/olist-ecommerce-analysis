-- Order-level reporting model: exactly one row per order.
--
-- Items, payments and reviews all have many rows per order. Joining them
-- directly would multiply rows and inflate totals (+4.5% item price and +26.9%
-- payment value, see docs/data_dictionary.md). Each one is therefore
-- aggregated to one row per order FIRST, then LEFT JOINed to clean_orders.
--
-- Rule for multiple reviews per order:
-- * 547 orders have 2 or 3 reviews, and in 202 of them the scores differ.
-- * The review with the LATEST review_answer_ts is kept, because it is the
--   customer's most recent opinion. No order has two reviews answered at the
--   same moment, so the choice is unique. review_id breaks ties as a safeguard.
-- * review_count keeps the number of reviews so the rule can be checked.
--
-- Delivery columns (filled only when is_valid_delivery = 1):
-- * delivery_days = days from purchase to customer delivery (with decimals).
-- * days_vs_estimate = delivery date minus estimated date, in whole days.
--   Positive = late, 0 = on the estimated day, negative = early.
-- * is_late = 1 when the delivery DATE is after the estimated DATE. The estimate
--   has no time part, so comparing full timestamps would count a delivery at
--   15:00 on the promised day as late. Comparing dates avoids that.

DROP TABLE IF EXISTS model_orders;

CREATE TABLE model_orders AS
WITH items AS (
    SELECT order_id,
           COUNT(*)                  AS item_count,
           COUNT(DISTINCT product_id) AS product_count,
           COUNT(DISTINCT seller_id)  AS seller_count,
           SUM(price)                AS merchandise_value,
           SUM(freight_value)        AS freight_value
    FROM clean_order_items
    GROUP BY order_id
),
payments_ranked AS (
    SELECT order_id,
           payment_type,
           payment_value,
           payment_installments,
           -- rank 1 = the payment record with the largest value in the order
           ROW_NUMBER() OVER (PARTITION BY order_id
                              ORDER BY payment_value DESC, payment_sequential) AS rn
    FROM clean_order_payments
),
payments AS (
    SELECT order_id,
           COUNT(*)                  AS payment_count,
           SUM(payment_value)        AS payment_value,
           MAX(payment_installments) AS max_installments,
           MAX(CASE WHEN rn = 1 THEN payment_type END) AS main_payment_type
    FROM payments_ranked
    GROUP BY order_id
),
reviews_ranked AS (
    SELECT order_id,
           review_id,
           review_score,
           has_comment_message,
           COUNT(*) OVER (PARTITION BY order_id) AS review_count,
           ROW_NUMBER() OVER (PARTITION BY order_id
                              ORDER BY review_answer_ts DESC, review_id) AS rn
    FROM clean_order_reviews
),
reviews AS (
    SELECT order_id, review_id, review_score, has_comment_message, review_count
    FROM reviews_ranked
    WHERE rn = 1
)
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.status_group,
    o.purchase_ts,
    o.purchase_date,
    o.purchase_month,
    o.delivered_ts,
    o.estimated_delivery_date,

    COALESCE(i.item_count, 0)        AS item_count,
    COALESCE(i.product_count, 0)     AS product_count,
    COALESCE(i.seller_count, 0)      AS seller_count,
    COALESCE(i.merchandise_value, 0) AS merchandise_value,
    COALESCE(i.freight_value, 0)     AS freight_value,

    COALESCE(p.payment_count, 0)     AS payment_count,
    p.payment_value,                 -- NULL when the order has no payment record
    p.max_installments,
    p.main_payment_type,

    r.review_id,
    r.review_score,                  -- NULL when the order has no review
    r.has_comment_message,
    COALESCE(r.review_count, 0)      AS review_count,

    o.is_valid_delivery,
    CASE WHEN o.is_valid_delivery = 1
         THEN julianday(o.delivered_ts) - julianday(o.purchase_ts) END AS delivery_days,
    CASE WHEN o.is_valid_delivery = 1
         THEN CAST(julianday(date(o.delivered_ts)) - julianday(o.estimated_delivery_date) AS INTEGER)
    END AS days_vs_estimate,
    CASE WHEN o.is_valid_delivery = 1
         THEN (date(o.delivered_ts) > o.estimated_delivery_date) END AS is_late,

    o.has_items,
    o.has_payment,
    o.has_review,
    o.flag_delivered_missing_date,
    o.flag_not_delivered_but_has_date,
    o.flag_carrier_before_purchase,
    o.flag_delivered_before_carrier
FROM clean_orders AS o
JOIN clean_customers AS c ON c.customer_id = o.customer_id
LEFT JOIN items    AS i ON i.order_id = o.order_id
LEFT JOIN payments AS p ON p.order_id = o.order_id
LEFT JOIN reviews  AS r ON r.order_id = o.order_id;
