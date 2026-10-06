-- =========================================================
-- DATA QUALITY CHECKS: RAW SALES
-- =========================================================


-- Check for duplicate sale IDs.
-- sale_id should uniquely identify each sales record.
SELECT
    sale_id,
    COUNT(*) AS duplicate_count
FROM raw.sales
GROUP BY sale_id
HAVING COUNT(*) > 1;


-- Count NULL values in each sales column.
SELECT
    COUNT(*) FILTER (WHERE sale_id IS NULL) AS sale_id_null,
    COUNT(*) FILTER (WHERE sale_date IS NULL) AS sale_date_null,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS product_id_null,
    COUNT(*) FILTER (WHERE quantity IS NULL) AS quantity_null,
    COUNT(*) FILTER (WHERE unit_price_eur IS NULL) AS unit_price_eur_null,
    COUNT(*) FILTER (WHERE discount_pct IS NULL) AS discount_pct_null,
    COUNT(*) FILTER (WHERE customer_type IS NULL) AS customer_type_null,
    COUNT(*) FILTER (WHERE sales_channel IS NULL) AS sales_channel_null,
    COUNT(*) FILTER (WHERE customer_region IS NULL) AS customer_region_null,
    COUNT(*) FILTER (WHERE order_status IS NULL) AS order_status_null
FROM raw.sales;


-- Find sales records with invalid quantities.
SELECT
    sale_id,
    quantity
FROM raw.sales
WHERE quantity <= 0;


-- Check the minimum and maximum quantity.
SELECT
    MIN(quantity) AS min_quantity,
    MAX(quantity) AS max_quantity
FROM raw.sales;


-- Find sales records with invalid unit prices.
SELECT
    sale_id,
    unit_price_eur
FROM raw.sales
WHERE unit_price_eur <= 0;


-- Check the minimum and maximum unit price.
SELECT
    MIN(unit_price_eur) AS min_unit_price,
    MAX(unit_price_eur) AS max_unit_price
FROM raw.sales;


-- Check the minimum and maximum discount.
-- Expected range: 0.00 to 0.20.
SELECT
    MIN(discount_pct) AS min_discount,
    MAX(discount_pct) AS max_discount
FROM raw.sales;


-- Find discounts outside the allowed range.
SELECT
    sale_id,
    discount_pct
FROM raw.sales
WHERE discount_pct < 0
   OR discount_pct > 0.20;


-- Check the data types of the raw sales table.
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'raw'
  AND table_name = 'sales'
ORDER BY ordinal_position;


-- Check the minimum and maximum sale dates.
SELECT
    MIN(sale_date) AS earliest_sale_date,
    MAX(sale_date) AS latest_sale_date
FROM raw.sales;


-- Check order status distribution.
SELECT
    order_status,
    COUNT(*) AS record_count
FROM raw.sales
GROUP BY order_status
ORDER BY record_count DESC;


-- Find invalid order status values.
SELECT
    sale_id,
    order_status
FROM raw.sales
WHERE order_status IS NOT NULL
  AND order_status NOT IN (
      'completed',
      'cancelled',
      'returned'
  );


-- Check customer type distribution.
SELECT
    customer_type,
    COUNT(*) AS record_count
FROM raw.sales
GROUP BY customer_type
ORDER BY record_count DESC;


-- Check sales channel distribution.
SELECT
    sales_channel,
    COUNT(*) AS record_count
FROM raw.sales
GROUP BY sales_channel
ORDER BY record_count DESC;


-- Find invalid sales channel values.
SELECT
    sale_id,
    sales_channel
FROM raw.sales
WHERE sales_channel IS NOT NULL
  AND sales_channel NOT IN (
      'direct',
      'wholesale'
  );


-- Check customer region distribution.
SELECT
    customer_region,
    COUNT(*) AS record_count
FROM raw.sales
GROUP BY customer_region
ORDER BY record_count DESC;


-- Find sales records whose product_id does not exist
-- in the products master table.
SELECT
    s.sale_id,
    s.product_id
FROM raw.sales AS s
LEFT JOIN raw.products AS p
    ON s.product_id = p.product_id
WHERE p.product_id IS NULL
  AND s.product_id IS NOT NULL;



-- =========================================================
-- DATA QUALITY CHECKS: RAW PRODUCTS
-- =========================================================


-- Check for duplicate product IDs.
SELECT
    product_id,
    COUNT(*) AS duplicate_count
FROM raw.products
GROUP BY product_id
HAVING COUNT(*) > 1;


-- Count NULL values in each products column.
SELECT
    COUNT(*) FILTER (WHERE product_id IS NULL) AS product_id_null,
    COUNT(*) FILTER (WHERE product_name IS NULL) AS product_name_null,
    COUNT(*) FILTER (WHERE category IS NULL) AS category_null,
    COUNT(*) FILTER (WHERE alcohol_percentage IS NULL) AS alcohol_percentage_null,
    COUNT(*) FILTER (WHERE package_size_l IS NULL) AS package_size_l_null,
    COUNT(*) FILTER (WHERE units_per_crate IS NULL) AS units_per_crate_null,
    COUNT(*) FILTER (
        WHERE list_price_per_crate_eur IS NULL
    ) AS list_price_per_crate_eur_null,
    COUNT(*) FILTER (WHERE active_since IS NULL) AS active_since_null
FROM raw.products;


-- Find products with invalid list prices.
SELECT
    product_id,
    product_name,
    list_price_per_crate_eur
FROM raw.products
WHERE list_price_per_crate_eur <= 0;


-- Find products with invalid package sizes.
SELECT
    product_id,
    product_name,
    package_size_l
FROM raw.products
WHERE package_size_l <= 0;


-- Find products with an invalid number of units per crate.
SELECT
    product_id,
    product_name,
    units_per_crate
FROM raw.products
WHERE units_per_crate <= 0;


-- Check the minimum and maximum alcohol percentage.
SELECT
    MIN(alcohol_percentage) AS min_alcohol_percentage,
    MAX(alcohol_percentage) AS max_alcohol_percentage
FROM raw.products;


-- Find alcohol percentages outside the expected range.
-- Expected range: 0 to 15 percentage points.
SELECT
    product_id,
    product_name,
    alcohol_percentage
FROM raw.products
WHERE alcohol_percentage < 0
   OR alcohol_percentage > 15;


-- Check available product categories.
SELECT DISTINCT
    category
FROM raw.products
ORDER BY category;