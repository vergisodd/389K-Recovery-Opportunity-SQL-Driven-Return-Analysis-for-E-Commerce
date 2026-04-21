-- =========================
-- 02_DATA_LOADING.SQL
-- ETL: staging_ecommerce -> normalized tables
-- =========================

-- NOTE:
-- This script assumes staging_ecommerce has already been loaded.
-- Dates in staging are expected in D/M/YYYY or DD/MM/YYYY format.

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
    MAX(customer_age) AS customer_age,
    MAX(customer_gender) AS customer_gender
FROM staging_ecommerce
GROUP BY customer_id;

-- =========================
-- 2. PRODUCTS
-- Keep one record per product
-- =========================
INSERT INTO products (product_id, category, price, discount)
SELECT
    product_id,
    MAX(category) AS category,
    MAX(price) AS price,
    MAX(discount) AS discount
FROM staging_ecommerce
GROUP BY product_id;

-- =========================
-- 3. ORDERS
-- Standardize D/M/YYYY and DD/MM/YYYY into YYYY-MM-DD
-- =========================
WITH order_dates AS (
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
        instr(order_date, '/') AS order_slash_1,
        instr(substr(order_date, instr(order_date, '/') + 1), '/') AS order_slash_2_rel,
        instr(delivered_date, '/') AS delivered_slash_1,
        instr(substr(delivered_date, instr(delivered_date, '/') + 1), '/') AS delivered_slash_2_rel
    FROM staging_ecommerce
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
        substr(order_date, 1, order_slash_1 - 1) AS order_day,
        substr(
            order_date,
            order_slash_1 + 1,
            order_slash_2_rel - 1
        ) AS order_month,
        substr(
            order_date,
            order_slash_1 + order_slash_2_rel + 1
        ) AS order_year,
        substr(delivered_date, 1, delivered_slash_1 - 1) AS delivered_day,
        substr(
            delivered_date,
            delivered_slash_1 + 1,
            delivered_slash_2_rel - 1
        ) AS delivered_month,
        substr(
            delivered_date,
            delivered_slash_1 + delivered_slash_2_rel + 1
        ) AS delivered_year
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
        CAST(order_year AS INTEGER),
        CAST(order_month AS INTEGER),
        CAST(order_day AS INTEGER)
    ) AS order_date,
    printf(
        '%04d-%02d-%02d',
        CAST(delivered_year AS INTEGER),
        CAST(delivered_month AS INTEGER),
        CAST(delivered_day AS INTEGER)
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
-- Load only confirmed returned orders
-- =========================
WITH return_dates AS (
    SELECT
        order_id,
        request_date,
        return_reason,
        instr(request_date, '/') AS request_slash_1,
        instr(substr(request_date, instr(request_date, '/') + 1), '/') AS request_slash_2_rel
    FROM staging_ecommerce
    WHERE returned = 'Yes'
),
parsed_returns AS (
    SELECT
        order_id,
        return_reason,
        substr(request_date, 1, request_slash_1 - 1) AS request_day,
        substr(
            request_date,
            request_slash_1 + 1,
            request_slash_2_rel - 1
        ) AS request_month,
        substr(
            request_date,
            request_slash_1 + request_slash_2_rel + 1
        ) AS request_year
    FROM return_dates
)
INSERT INTO returns (order_id, request_date, return_reason)
SELECT
    order_id,
    printf(
        '%04d-%02d-%02d',
        CAST(request_year AS INTEGER),
        CAST(request_month AS INTEGER),
        CAST(request_day AS INTEGER)
    ) AS request_date,
    return_reason
FROM parsed_returns;
