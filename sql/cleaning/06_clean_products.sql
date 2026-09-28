-- Clean products: one row per product.
--
-- Category rules:
-- * The English name comes from raw_category_translation.
-- * Two Portuguese categories are missing from the translation file. They are
--   translated here by hand so their sales are not lost in an "unknown" group:
--     pc_gamer -> pc_gamer
--     portateis_cozinha_e_preparadores_de_alimentos -> portable_kitchen_and_food_preparers
-- * Products with no category (610) get 'unknown'. They are kept because their
--   items still count towards sales; they are reported as their own group.
--
-- Other rules:
-- * Misspelled source columns are renamed (product_name_lenght -> product_name_length).
-- * Size and weight columns are converted to numbers; 2 products have none and stay NULL.
-- * A weight of 0 g is not possible for a shipped product. The value is kept and
--   flagged; weight is not used to answer the business questions.

DROP TABLE IF EXISTS manual_category_translation;

CREATE TABLE manual_category_translation (
    product_category_name         TEXT PRIMARY KEY,
    product_category_name_english TEXT NOT NULL
);

INSERT INTO manual_category_translation VALUES
    ('pc_gamer', 'pc_gamer'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_and_food_preparers');


DROP TABLE IF EXISTS clean_products;

CREATE TABLE clean_products AS
SELECT
    p.product_id,
    p.product_category_name AS category_pt,
    CASE
        WHEN p.product_category_name IS NULL THEN 'unknown'
        ELSE COALESCE(t.product_category_name_english,
                      m.product_category_name_english,
                      p.product_category_name)
    END AS category,
    (p.product_category_name IS NULL) AS flag_missing_category,
    (t.product_category_name IS NULL AND m.product_category_name IS NOT NULL)
        AS flag_manual_translation,
    COALESCE(CAST(p.product_weight_g AS REAL) = 0, 0) AS flag_zero_weight,
    CAST(p.product_name_lenght AS INTEGER)        AS product_name_length,
    CAST(p.product_description_lenght AS INTEGER) AS product_description_length,
    CAST(p.product_photos_qty AS INTEGER)         AS product_photos_qty,
    CAST(p.product_weight_g AS REAL)              AS product_weight_g,
    CAST(p.product_length_cm AS REAL)             AS product_length_cm,
    CAST(p.product_height_cm AS REAL)             AS product_height_cm,
    CAST(p.product_width_cm AS REAL)              AS product_width_cm
FROM raw_products AS p
LEFT JOIN raw_category_translation AS t
       ON t.product_category_name = p.product_category_name
LEFT JOIN manual_category_translation AS m
       ON m.product_category_name = p.product_category_name;
