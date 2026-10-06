-- =========================================================
-- 1. Create staging.weather
-- =========================================================

DROP TABLE IF EXISTS staging.weather;

CREATE TABLE staging.weather AS
SELECT
    weather_date::DATE AS weather_date,
    temperature_2m_mean,
    temperature_2m_max,
    temperature_2m_min,
    precipitation_sum,
    weather_code
FROM raw.weather
WHERE weather_date IS NOT NULL
  AND precipitation_sum >= 0;


-- =========================================================
-- 2. Validate staging.weather
-- =========================================================

-- Row count
SELECT COUNT(*) AS staging_weather_count
FROM staging.weather;

-- Check data types
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'staging'
  AND table_name = 'weather';

-- Check duplicate dates
SELECT
    weather_date,
    COUNT(*) AS count_rows
FROM staging.weather
GROUP BY weather_date
HAVING COUNT(*) > 1;

-- Compare raw and staging row counts
SELECT
    (SELECT COUNT(*) FROM raw.weather) AS raw_count,
    (SELECT COUNT(*) FROM staging.weather) AS staging_count;


-- =========================================================
-- 3. Check JOIN between sales and weather
-- =========================================================

SELECT
    ds.sale_date,
    ds.product_id,
    ds.product_name,
    ds.category,
    ds.total_revenue_eur,
    ds.total_quantity,
    ds.sales_count,
    w.temperature_2m_mean,
    w.temperature_2m_max,
    w.temperature_2m_min,
    w.precipitation_sum,
    w.weather_code
FROM mart.daily_sales AS ds
JOIN staging.weather AS w
    ON ds.sale_date = w.weather_date
LIMIT 10;


-- =========================================================
-- 4. Create mart.daily_sales_weather
-- =========================================================

DROP TABLE IF EXISTS mart.daily_sales_weather;

CREATE TABLE mart.daily_sales_weather AS
SELECT
    ds.sale_date,
    ds.product_id,
    ds.product_name,
    ds.category,
    ds.total_revenue_eur,
    ds.total_quantity,
    ds.sales_count,
    w.temperature_2m_mean,
    w.temperature_2m_max,
    w.temperature_2m_min,
    w.precipitation_sum,
    w.weather_code
FROM mart.daily_sales AS ds
JOIN staging.weather AS w
    ON ds.sale_date = w.weather_date;


-- =========================================================
-- 5. Validate mart.daily_sales_weather
-- =========================================================

-- Row count
SELECT COUNT(*) AS daily_sales_weather_count
FROM mart.daily_sales_weather;

-- Compare counts before and after JOIN
SELECT
    (SELECT COUNT(*) FROM mart.daily_sales) AS daily_sales_count,
    (SELECT COUNT(*) FROM mart.daily_sales_weather) AS daily_sales_weather_count;

-- Preview result
SELECT *
FROM mart.daily_sales_weather
LIMIT 10;