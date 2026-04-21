-- =========================
-- 02_DATA_LOADING.SQL
-- ETL: staging_ecommerce -> normalized tables
-- =========================

-- NOTE:
-- This script assumes staging_ecommerce has already been loaded.
-- Dates in staging are expected in D/M/YYYY or DD/MM/YYYY format.
-- Duplicate order_id rows are deduplicated using ROW_NUMBER() before loading.

PRAGMA foreign_keys = ON;

-- =========================
-- 0. Clear existing data
-- =========================
DELETE FROM returns;
DELETE FROM orders;
DELETE FROM products;
DELETE FROM customers;

-- =========================
-- 1. CUSTOMERS
-- Keep one record per customer
-- =========================
INSERT INTO customers (customer_id, customer_age, customer_gender)
SELECT
    customer_id,
    MAX(customer_age)    AS customer_age,
    MAX(customer_gender) AS customer_gender
FROM staging_ecommerce
GROUP BY customer_id;

-- =========================
-- 2. PRODUCTS
-- Keep one record per product.
--
-- CATEGORY CONFLICT RESOLUTION:
-- The staging layer contains category mismatches — the same product_id
-- appears with different category values across rows. This is a data
-- quality issue in the source dataset, not an ETL error.
--
-- Resolution strategy (in priority order):
--   1. If one category appears more frequently than all others for a
--      product_id, use that category (modal value).
--   2. If two or more categories are tied in frequency (true ambiguity),
--      use alphabetical order as a deterministic tie-breaker so results
--      are reproducible across runs.
--
-- NOTE: ~75% of conflicted products are true 1v1 ties — they appear
-- exactly once with two different categories and cannot be resolved from
-- frequency alone. The alphabetical tie-breaker makes the output
-- deterministic, but the underlying ambiguity should be flagged in
-- 07_data_validation.sql and addressed at the source if category accuracy
-- is critical to the analysis.
-- =========================

-- 2a. Pre-load audit: surface all products with category conflicts
--     so the extent of the issue is visible before data is loaded.
--     Run this block independently to inspect conflicts.
-- SELECT
--     product_id,
--     COUNT(DISTINCT category) AS unique_category_count,
--     GROUP_CONCAT(DISTINCT category) AS categories_seen
-- FROM staging_ecommerce
-- GROUP BY product_id
-- HAVING COUNT(DISTINCT category) > 1
-- ORDER BY unique_category_count DESC, product_id;

-- 2b. Insert products using modal category with alphabetical tie-breaker
INSERT INTO products (product_id, category, price, discount)
SELECT
    product_id,
    (
        -- For each product_id, select the category that appears most often.
        -- ORDER BY COUNT(*) DESC picks the modal value.
        -- ORDER BY category ASC as a secondary sort makes ties deterministic:
        -- when two categories appear equally often, the alphabetically first
        -- one is selected consistently on every run.
        SELECT   category
        FROM     staging_ecommerce s2
        WHERE    s2.product_id = s.product_id
        GROUP BY category
        ORDER BY COUNT(*) DESC, category ASC
        LIMIT 1
    )             AS category,
    MAX(price)    AS price,
    MAX(discount) AS discount
FROM staging_ecommerce s
GROUP BY product_id;

-- =========================
-- 3. ORDERS
-- Deduplicate by order_id using ROW_NUMBER() before parsing dates.
-- Standardize D/M/YYYY and DD/MM/YYYY into YYYY-MM-DD using
-- instr/substr since SQLite has no native date parsing for this format.
-- =========================
WITH deduped AS (
    -- Keep only the first occurrence of each order_id.
    -- ROW_NUMBER() partitions by order_id and assigns rank 1
    -- to the first row seen; all subsequent duplicates are filtered out.
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY rowid) AS rn
    FROM staging_ecommerce
),
order_dates AS (
    SELECT
        order_id,
        customer_id,
        product_id,
        quantity,
        payment_method,
        region,
        total_amount,
        shipping_cost,
        profit_margin,
        order_date,
        delivered_date,
        instr(order_date, '/')                                              AS order_slash_1,
        instr(substr(order_date, instr(order_date, '/') + 1), '/')         AS order_slash_2_rel,
        instr(delivered_date, '/')                                          AS delivered_slash_1,
        instr(substr(delivered_date, instr(delivered_date, '/') + 1), '/') AS delivered_slash_2_rel
    FROM deduped
    WHERE rn = 1   -- deduplicated here, before any date parsing
),
parsed_orders AS (
    SELECT
        order_id,
        customer_id,
        product_id,
        quantity,
        payment_method,
        region,
        total_amount,
        shipping_cost,
        profit_margin,
        substr(order_date, 1, order_slash_1 - 1)                     AS order_day,
        substr(
            order_date,
            order_slash_1 + 1,
            order_slash_2_rel - 1
        )                                                             AS order_month,
        substr(
            order_date,
            order_slash_1 + order_slash_2_rel + 1
        )                                                             AS order_year,
        substr(delivered_date, 1, delivered_slash_1 - 1)             AS delivered_day,
        substr(
            delivered_date,
            delivered_slash_1 + 1,
            delivered_slash_2_rel - 1
        )                                                             AS delivered_month,
        substr(
            delivered_date,
            delivered_slash_1 + delivered_slash_2_rel + 1
        )                                                             AS delivered_year
    FROM order_dates
)
INSERT INTO orders (
    order_id,
    customer_id,
    product_id,
    order_date,
    delivered_date,
    quantity,
    payment_method,
    region,
    total_amount,
    shipping_cost,
    profit_margin
)
SELECT
    order_id,
    customer_id,
    product_id,
    printf(
        '%04d-%02d-%02d',
        CAST(order_year  AS INTEGER),
        CAST(order_month AS INTEGER),
        CAST(order_day   AS INTEGER)
    ) AS order_date,
    printf(
        '%04d-%02d-%02d',
        CAST(delivered_year  AS INTEGER),
        CAST(delivered_month AS INTEGER),
        CAST(delivered_day   AS INTEGER)
    ) AS delivered_date,
    quantity,
    payment_method,
    region,
    total_amount,
    shipping_cost,
    profit_margin
FROM parsed_orders;

-- =========================
-- 4. RETURNS
-- Deduplicate by order_id before loading.
-- Load only confirmed returned orders (returned = 'Yes').
-- =========================
WITH deduped_returns AS (
    -- A single order can only have one return record.
    -- If the staging layer contains duplicates, keep only the first.
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY rowid) AS rn
    FROM staging_ecommerce
    WHERE returned = 'Yes'
),
return_dates AS (
    SELECT
        order_id,
        request_date,
        return_reason,
        instr(request_date, '/')                                             AS request_slash_1,
        instr(substr(request_date, instr(request_date, '/') + 1), '/')      AS request_slash_2_rel
    FROM deduped_returns
    WHERE rn = 1   -- deduplicated here, before date parsing
),
parsed_returns AS (
    SELECT
        order_id,
        return_reason,
        substr(request_date, 1, request_slash_1 - 1)                  AS request_day,
        substr(
            request_date,
            request_slash_1 + 1,
            request_slash_2_rel - 1
        )                                                              AS request_month,
        substr(
            request_date,
            request_slash_1 + request_slash_2_rel + 1
        )                                                              AS request_year
    FROM return_dates
)
INSERT INTO returns (order_id, request_date, return_reason)
SELECT
    order_id,
    printf(
        '%04d-%02d-%02d',
        CAST(request_year  AS INTEGER),
        CAST(request_month AS INTEGER),
        CAST(request_day   AS INTEGER)
    ) AS request_date,
    return_reason
FROM parsed_returns;
