-- Clean customers: one row per customer_id.
--
-- Rules:
-- * customer_id is created for every order; customer_unique_id identifies the person.
--   Both are kept. Customer-level analysis must use customer_unique_id.
-- * Zip code prefixes stay as text so leading zeros are not lost (e.g. '01037').
-- * City is lower-cased and state upper-cased with spaces trimmed. The raw data is
--   already consistent, so this is a safety step that changes no values today.

DROP TABLE IF EXISTS clean_customers;

CREATE TABLE clean_customers AS
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    LOWER(TRIM(customer_city))  AS customer_city,
    UPPER(TRIM(customer_state)) AS customer_state
FROM raw_customers;
