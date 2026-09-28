-- Clean sellers: one row per seller.
-- Same text rules as customers. Zip code prefixes stay as text.

DROP TABLE IF EXISTS clean_sellers;

CREATE TABLE clean_sellers AS
SELECT
    seller_id,
    seller_zip_code_prefix,
    LOWER(TRIM(seller_city))  AS seller_city,
    UPPER(TRIM(seller_state)) AS seller_state
FROM raw_sellers;
