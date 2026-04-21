-- =========================
-- 07_DATA_VALIDATION.SQL
-- Data quality and ETL reconciliation checks
-- =========================

-- 1. Row count reconciliation
-- Compare raw staging volume to loaded fact/return tables
SELECT COUNT(*) AS staging_row_count
FROM staging_ecommerce;

SELECT
    COUNT(*) AS orders_count
FROM orders;

SELECT
    COUNT(*) AS returns_count
FROM returns;

-- 2. Duplicate check in staging
-- Orders should be unique before loading into the normalized model
SELECT
    order_id,
    COUNT(*) AS duplicate_count
FROM staging_ecommerce
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 3. Revenue reconciliation
-- Revenue in staging should match revenue in the cleaned orders table
SELECT
    ROUND(SUM(total_amount), 2) AS staging_total_revenue
FROM staging_ecommerce;

SELECT
    ROUND(SUM(total_amount), 2) AS orders_total_revenue
FROM orders;

-- 4. Return consistency
-- Every return record should map to a valid order
SELECT
    COUNT(*) AS unmatched_returns
FROM returns r
LEFT JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 5. Missing key checks
-- Important identifiers should not be null in the normalized model
SELECT
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS missing_customer_id,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS missing_product_id,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS missing_order_date
FROM orders;

-- 6. Date quality check
-- Delivered date should not be earlier than order date
SELECT
    COUNT(*) AS invalid_delivery_dates
FROM orders
WHERE delivered_date < order_date;
