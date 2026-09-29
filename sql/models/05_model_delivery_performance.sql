-- Delivery-performance summary: one row per customer state.
--
-- Rules:
-- * Only orders with is_valid_delivery = 1 (delivered status, a delivery date
--   exists and it is not before the purchase).
-- * Late = delivery date after the estimated delivery date (see model_orders).
-- * Review columns use orders that have a review; reviewed_orders gives the
--   sample size behind avg_review_score.
-- * States with few deliveries give unstable rates. The analysis queries apply
--   a minimum-volume threshold; this table keeps every state.

DROP TABLE IF EXISTS model_delivery_performance;

CREATE TABLE model_delivery_performance AS
SELECT
    customer_state,
    COUNT(*)                                  AS valid_deliveries,
    ROUND(AVG(delivery_days), 2)              AS avg_delivery_days,
    SUM(is_late)                              AS late_deliveries,
    ROUND(100.0 * SUM(is_late) / COUNT(*), 2) AS late_rate_pct,
    ROUND(AVG(CASE WHEN is_late = 1 THEN days_vs_estimate END), 2) AS avg_days_late_when_late,
    ROUND(AVG(-days_vs_estimate), 2)          AS avg_days_early_vs_estimate,
    COUNT(review_score)                       AS reviewed_orders,
    ROUND(AVG(review_score), 3)               AS avg_review_score
FROM model_orders
WHERE is_valid_delivery = 1
GROUP BY customer_state
ORDER BY valid_deliveries DESC;
