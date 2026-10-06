-- =========================================================
-- MART SCHEMA
-- =========================================================

CREATE SCHEMA IF NOT EXISTS mart;



-- =========================================================
-- DIMENSION: PRODUCTS
-- =========================================================

-- Product dimension containing descriptive product attributes
-- from the cleaned staging layer.
DROP TABLE IF EXISTS mart.dim_products;

CREATE TABLE mart.dim_products AS
SELECT
    product_id,
    product_name,
    category,
    alcohol_percentage,
    package_size_l,
    units_per_crate,
    list_price_per_crate_eur,
    active_since
FROM staging.products;



-- =========================================================
-- FACT TABLE: SALES
-- =========================================================

-- Sales fact table containing individual sales records.
-- revenue_eur is calculated after applying the discount.
DROP TABLE IF EXISTS mart.fact_sales;

CREATE TABLE mart.fact_sales AS
SELECT
    sale_id,
    sale_date,
    product_id,
    quantity,
    unit_price_eur,
    discount_pct,
    customer_type,
    sales_channel,
    customer_region,
    order_status,
    quantity * unit_price_eur * (1 - discount_pct) AS revenue_eur
FROM staging.sales;



-- =========================================================
-- MART: DAILY SALES
-- =========================================================

-- Aggregated daily sales per product.
-- Only completed sales are included in revenue and quantity calculations.
DROP TABLE IF EXISTS mart.daily_sales;

CREATE TABLE mart.daily_sales AS
SELECT
    s.sale_date,
    s.product_id,
    p.product_name,
    p.category,
    SUM(s.revenue_eur) AS total_revenue_eur,
    SUM(s.quantity) AS total_quantity,
    COUNT(*) AS sales_count
FROM mart.fact_sales AS s
JOIN mart.dim_products AS p
    ON s.product_id = p.product_id
WHERE s.order_status = 'completed'
GROUP BY
    s.sale_date,
    s.product_id,
    p.product_name,
    p.category;



-- =========================================================
-- DIMENSION: DATE
-- =========================================================

-- Date dimension containing calendar attributes
-- used for time-based analytics.
DROP TABLE IF EXISTS mart.dim_date;

CREATE TABLE mart.dim_date AS
SELECT DISTINCT
    sale_date,
    EXTRACT(YEAR FROM sale_date) AS year,
    EXTRACT(MONTH FROM sale_date) AS month,
    EXTRACT(DAY FROM sale_date) AS day,
    EXTRACT(QUARTER FROM sale_date) AS quarter,
    EXTRACT(DOW FROM sale_date) AS weekday,
    TO_CHAR(sale_date, 'Dy') AS weekday_str,
    EXTRACT(DOW FROM sale_date) IN (0, 6) AS is_weekend
FROM mart.fact_sales;


-- Validate that each date appears only once in the date dimension
SELECT COUNT(*) AS dim_date_count
FROM mart.dim_date;

SELECT COUNT(DISTINCT sale_date) AS distinct_fact_dates
FROM mart.fact_sales;



-- =========================================================
-- MART: PRODUCT PERFORMANCE
-- =========================================================

-- Product-level performance metrics.
-- Only completed sales are included.
DROP TABLE IF EXISTS mart.product_performance;

CREATE TABLE mart.product_performance AS
SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(s.quantity) AS total_quantity,
    SUM(s.revenue_eur) AS total_revenue_eur,
    COUNT(s.sale_id) AS sales_count,
    AVG(s.revenue_eur) AS avg_revenue_per_sale
FROM mart.dim_products AS p
JOIN mart.fact_sales AS s
    ON p.product_id = s.product_id
WHERE s.order_status = 'completed'
GROUP BY
    p.product_id,
    p.product_name,
    p.category;



-- =========================================================
-- MART: REGION SALES
-- =========================================================

-- Regional sales performance.
-- Only completed sales are included.
DROP TABLE IF EXISTS mart.region_sales;

CREATE TABLE mart.region_sales AS
SELECT
    customer_region,
    SUM(revenue_eur) AS total_revenue_eur,
    SUM(quantity) AS total_quantity,
    COUNT(sale_id) AS sales_count
FROM mart.fact_sales
WHERE order_status = 'completed'
GROUP BY customer_region
ORDER BY total_revenue_eur DESC;



-- =========================================================
-- FINAL VALIDATION
-- =========================================================

-- Check row counts for the main MART tables
SELECT COUNT(*) AS dim_products_count
FROM mart.dim_products;

SELECT COUNT(*) AS fact_sales_count
FROM mart.fact_sales;

SELECT COUNT(*) AS daily_sales_count
FROM mart.daily_sales;

SELECT COUNT(*) AS dim_date_count
FROM mart.dim_date;

SELECT COUNT(*) AS product_performance_count
FROM mart.product_performance;

SELECT COUNT(*) AS region_sales_count
FROM mart.region_sales;


-- Preview the final analytical tables
SELECT *
FROM mart.daily_sales
ORDER BY sale_date DESC
LIMIT 20;

SELECT *
FROM mart.product_performance
ORDER BY total_revenue_eur DESC;

SELECT *
FROM mart.region_sales
ORDER BY total_revenue_eur DESC;