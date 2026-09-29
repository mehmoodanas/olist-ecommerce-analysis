-- Validation: timestamp sequences.
--
-- Known problems (166 carrier-before-purchase, 23 delivered-before-carrier) are
-- flagged in cleaning and do not affect the metrics, because delivery time is
-- measured from purchase to customer delivery. These checks make sure:
-- * the timestamps used in metrics are always in a possible order, and
-- * every known problem is still flagged (flag count = recomputed count).


-- name: timestamp_sequences
SELECT 'valid deliveries with negative delivery time' AS check_name, 0 AS expected,
       SUM(delivery_days < 0) AS actual
FROM model_orders
WHERE is_valid_delivery = 1
UNION ALL
SELECT 'any order delivered before purchase', 0,
       SUM(delivered_ts < purchase_ts)
FROM clean_orders
UNION ALL
SELECT 'any order approved before purchase', 0,
       SUM(approved_ts < purchase_ts)
FROM clean_orders
UNION ALL
SELECT 'carrier before purchase: flagged = found',
       SUM(carrier_ts < purchase_ts),
       SUM(flag_carrier_before_purchase)
FROM clean_orders
UNION ALL
SELECT 'delivered before carrier: flagged = found',
       SUM(delivered_ts < carrier_ts),
       SUM(flag_delivered_before_carrier)
FROM clean_orders
UNION ALL
SELECT 'orders purchased outside the data period (2016-09-04 to 2018-10-17)', 0,
       SUM(purchase_date < '2016-09-04' OR purchase_date > '2018-10-17')
FROM clean_orders;
