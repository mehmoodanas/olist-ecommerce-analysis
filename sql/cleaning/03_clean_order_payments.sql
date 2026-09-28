-- Clean payments: one row per payment record (order_id + payment_sequential).
--
-- Rules:
-- * Numbers converted to INTEGER / REAL.
-- * Zero-value payments, zero instalments and payment_type 'not_defined'
--   are kept but flagged. They are few (see reports/data_quality.md) and
--   removing them would change payment totals without a clear reason.

DROP TABLE IF EXISTS clean_order_payments;

CREATE TABLE clean_order_payments AS
SELECT
    order_id,
    CAST(payment_sequential AS INTEGER)   AS payment_sequential,
    payment_type,
    CAST(payment_installments AS INTEGER) AS payment_installments,
    CAST(payment_value AS REAL)           AS payment_value,
    (CAST(payment_value AS REAL) = 0)          AS flag_zero_value,
    (CAST(payment_installments AS INTEGER) = 0) AS flag_zero_installments,
    (payment_type = 'not_defined')             AS flag_type_not_defined
FROM raw_order_payments;
