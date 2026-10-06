-- =========================================================
-- STAGING LAYER
-- =========================================================

CREATE SCHEMA IF NOT EXISTS staging;


-- =========================================================
-- STAGING PRODUCTS
-- =========================================================

-- Drop sales first because it depends on product data.
DROP TABLE IF EXISTS staging.sales;
DROP TABLE IF EXISTS staging.products;


CREATE TABLE staging.products AS
SELECT
    product_id,
    product_name,
    category,
    alcohol_percentage,
    package_size_l,
    units_per_crate,
    list_price_per_crate_eur,
    active_since::date AS active_since
FROM raw.products
WHERE product_id IS NOT NULL
  AND product_name IS NOT NULL
  AND category IS NOT NULL
  AND alcohol_percentage BETWEEN 0 AND 15
  AND package_size_l > 0
  AND units_per_crate > 0
  AND list_price_per_crate_eur > 0
  AND active_since IS NOT NULL;


-- Enforce unique product IDs in the staging layer.
ALTER TABLE staging.products
ADD PRIMARY KEY (product_id);



-- =========================================================
-- STAGING SALES
-- =========================================================

CREATE TABLE staging.sales AS

WITH ranked_sales AS (
    SELECT
        sale_id,
        sale_date::date AS sale_date,
        product_id,
        quantity,
        unit_price_eur,
        discount_pct,
        customer_type,
        sales_channel,
        customer_region,
        order_status,

        ROW_NUMBER() OVER (
            PARTITION BY sale_id
            ORDER BY sale_date NULLS LAST
        ) AS rn

    FROM raw.sales
)

SELECT
    s.sale_id,
    s.sale_date,
    s.product_id,
    s.quantity,
    s.unit_price_eur,
    s.discount_pct,
    COALESCE(
        s.customer_type,
        'unknown'
    ) AS customer_type,
    s.sales_channel,
    s.customer_region,
    s.order_status

FROM ranked_sales AS s

INNER JOIN staging.products AS p
    ON s.product_id = p.product_id

WHERE s.rn = 1
  AND s.sale_id IS NOT NULL
  AND s.sale_date IS NOT NULL
  AND s.quantity > 0
  AND s.unit_price_eur > 0
  AND s.discount_pct BETWEEN 0 AND 0.20
  AND s.customer_region IS NOT NULL
  AND s.order_status IN (
      'completed',
      'cancelled',
      'returned'
  )
  AND s.sales_channel IN (
      'direct',
      'wholesale'
  );


-- sale_id must be unique after deduplication.
ALTER TABLE staging.sales
ADD PRIMARY KEY (sale_id);