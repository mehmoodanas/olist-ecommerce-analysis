-- Clean reviews: one row per review_id + order_id pair.
--
-- Rules:
-- * review_score converted to INTEGER (all values are 1-5).
-- * Comment text is not needed for the analysis, so only "has comment"
--   flags are kept. Empty or blank comments count as no comment.
-- * Orders with more than one review are NOT resolved here. The rule for
--   choosing one review per order is applied in the order-level model.

DROP TABLE IF EXISTS clean_order_reviews;

CREATE TABLE clean_order_reviews AS
SELECT
    review_id,
    order_id,
    CAST(review_score AS INTEGER)      AS review_score,
    datetime(review_creation_date)     AS review_creation_ts,
    datetime(review_answer_timestamp)  AS review_answer_ts,
    (TRIM(COALESCE(review_comment_title, '')) <> '')   AS has_comment_title,
    (TRIM(COALESCE(review_comment_message, '')) <> '') AS has_comment_message
FROM raw_order_reviews;
