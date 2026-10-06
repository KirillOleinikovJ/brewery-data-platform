-- =========================================================
-- DATA QUALITY CHECKS: RAW WEATHER
-- =========================================================


-- Check for duplicate weather dates.
SELECT
    weather_date,
    COUNT(*) AS duplicate_count
FROM raw.weather
WHERE weather_date IS NOT NULL
GROUP BY weather_date
HAVING COUNT(*) > 1;


-- Count NULL values in each column.
SELECT
    COUNT(*) FILTER (
        WHERE weather_date IS NULL
    ) AS weather_date_null,

    COUNT(*) FILTER (
        WHERE temperature_2m_mean IS NULL
    ) AS temperature_2m_mean_null,

    COUNT(*) FILTER (
        WHERE temperature_2m_max IS NULL
    ) AS temperature_2m_max_null,

    COUNT(*) FILTER (
        WHERE temperature_2m_min IS NULL
    ) AS temperature_2m_min_null,

    COUNT(*) FILTER (
        WHERE precipitation_sum IS NULL
    ) AS precipitation_sum_null,

    COUNT(*) FILTER (
        WHERE weather_code IS NULL
    ) AS weather_code_null

FROM raw.weather;


-- Check the covered weather period.
SELECT
    MIN(weather_date) AS earliest_weather_date,
    MAX(weather_date) AS latest_weather_date
FROM raw.weather;


-- Check temperature ranges.
SELECT
    MIN(temperature_2m_mean) AS min_mean_temperature,
    MAX(temperature_2m_mean) AS max_mean_temperature,

    MIN(temperature_2m_max) AS min_max_temperature,
    MAX(temperature_2m_max) AS max_max_temperature,

    MIN(temperature_2m_min) AS min_min_temperature,
    MAX(temperature_2m_min) AS max_min_temperature
FROM raw.weather;


-- Check precipitation range.
SELECT
    MIN(precipitation_sum) AS min_precipitation,
    MAX(precipitation_sum) AS max_precipitation
FROM raw.weather;


-- Find invalid negative precipitation values.
-- Expected result: 0 rows.
SELECT
    weather_date,
    precipitation_sum
FROM raw.weather
WHERE precipitation_sum < 0;

-- =========================================================
-- STAGING WEATHER
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
