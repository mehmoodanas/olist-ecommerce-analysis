-- Review scores and delivery timing.
--
-- Rules:
-- * One review per order (latest answered review, see sql/models/02_model_orders.sql).
-- * Only valid deliveries, so late / on-time is known.
-- * Orders without a review are excluded from score averages; coverage is reported.
-- * These are associations. Late orders may differ in other ways (region,
--   product, seller), so the gap is not proof that lateness causes low scores.


-- name: review_coverage
SELECT
    status_group,
    COUNT(*)                                          AS orders,
    COUNT(review_score)                               AS orders_with_review,
    ROUND(100.0 * COUNT(review_score) / COUNT(*), 2)  AS pct_with_review,
    ROUND(AVG(review_score), 3)                       AS avg_review_score
FROM model_orders
GROUP BY status_group
ORDER BY orders DESC;


-- name: review_late_vs_on_time
SELECT
    CASE WHEN is_late = 1 THEN 'late' ELSE 'on time' END AS delivery_status,
    COUNT(*)                                           AS valid_deliveries,
    COUNT(review_score)                                AS reviewed_orders,
    ROUND(AVG(review_score), 3)                        AS avg_review_score,
    ROUND(100.0 * SUM(review_score <= 2) / COUNT(review_score), 2) AS pct_1_or_2_stars,
    ROUND(100.0 * SUM(review_score = 5) / COUNT(review_score), 2)  AS pct_5_stars
FROM model_orders
WHERE is_valid_delivery = 1
GROUP BY delivery_status
ORDER BY delivery_status DESC;


-- name: review_by_days_vs_estimate
-- Finer bands: negative = delivered before the estimated date.
-- Bands with fewer than 100 reviewed orders are excluded.
SELECT
    CASE
        WHEN days_vs_estimate <= -15 THEN '1: 15+ days early'
        WHEN days_vs_estimate <= -8  THEN '2: 8-14 days early'
        WHEN days_vs_estimate <= -1  THEN '3: 1-7 days early'
        WHEN days_vs_estimate = 0    THEN '4: on the estimated day'
        WHEN days_vs_estimate <= 3   THEN '5: 1-3 days late'
        WHEN days_vs_estimate <= 7   THEN '6: 4-7 days late'
        WHEN days_vs_estimate <= 14  THEN '7: 8-14 days late'
        ELSE '8: 15+ days late'
    END AS delivery_band,
    COUNT(review_score)                                AS reviewed_orders,
    ROUND(AVG(review_score), 3)                        AS avg_review_score,
    ROUND(100.0 * SUM(review_score <= 2) / COUNT(review_score), 2) AS pct_1_or_2_stars
FROM model_orders
WHERE is_valid_delivery = 1
GROUP BY delivery_band
HAVING COUNT(review_score) >= 100
ORDER BY delivery_band;


-- name: review_late_vs_on_time_by_state
-- Checks whether the late vs on-time gap holds inside states, not only overall
-- (states differ in both late rate and scores). States need at least 100
-- reviewed late orders.
SELECT
    customer_state,
    SUM(is_late = 1 AND review_score IS NOT NULL)                AS reviewed_late,
    SUM(is_late = 0 AND review_score IS NOT NULL)                AS reviewed_on_time,
    ROUND(AVG(CASE WHEN is_late = 1 THEN review_score END), 3)   AS avg_score_late,
    ROUND(AVG(CASE WHEN is_late = 0 THEN review_score END), 3)   AS avg_score_on_time
FROM model_orders
WHERE is_valid_delivery = 1
GROUP BY customer_state
HAVING SUM(is_late = 1 AND review_score IS NOT NULL) >= 100
ORDER BY reviewed_late DESC;
