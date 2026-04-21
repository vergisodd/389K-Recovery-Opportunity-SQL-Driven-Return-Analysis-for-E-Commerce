-- =========================
-- 07_DATA_VALIDATION.SQL
-- Data quality and ETL reconciliation checks
-- Each check returns a PASS/FAIL result alongside the raw value.
-- A passing pipeline should produce PASS on every check.
-- =========================

-- =========================
-- 1. Row count reconciliation
-- Orders loaded into the normalized table should not exceed
-- the number of unique order_ids in staging (deduplication may reduce it).
-- =========================
SELECT
    CASE
        WHEN orders_count <= staging_unique_orders THEN 'PASS'
        ELSE 'FAIL — more orders loaded than unique staging rows'
    END AS check_result,
    staging_unique_orders,
    orders_count
FROM (
    SELECT
        (SELECT COUNT(DISTINCT order_id) FROM staging_ecommerce) AS staging_unique_orders,
        (SELECT COUNT(*)                 FROM orders)             AS orders_count
);

-- =========================
-- 2. Duplicate check in orders
-- After ETL, order_id must be unique in the normalized table.
-- Any result other than 0 means the deduplication step failed.
-- =========================
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL — duplicate order_ids exist in orders table'
    END AS check_result,
    COUNT(*) AS duplicate_order_count
FROM (
    SELECT order_id
    FROM orders
    GROUP BY order_id
    HAVING COUNT(*) > 1
);

-- =========================
-- 3. Revenue reconciliation
-- Total revenue in the normalized orders table must match staging.
-- A difference greater than $0.01 indicates a loading error.
-- =========================
SELECT
    CASE
        WHEN ABS(staging_revenue - orders_revenue) <= 0.01 THEN 'PASS'
        ELSE 'FAIL — revenue mismatch between staging and orders table'
    END AS check_result,
    staging_revenue,
    orders_revenue,
    ROUND(ABS(staging_revenue - orders_revenue), 2) AS difference
FROM (
    SELECT
        (SELECT ROUND(SUM(total_amount), 2) FROM staging_ecommerce) AS staging_revenue,
        (SELECT ROUND(SUM(total_amount), 2) FROM orders)             AS orders_revenue
);

-- =========================
-- 4. Orphaned returns check
-- Every return record must map to a valid order in the orders table.
-- Any orphaned return indicates a referential integrity failure.
-- =========================
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL — return records exist with no matching order'
    END AS check_result,
    COUNT(*) AS orphaned_return_count
FROM returns r
LEFT JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- =========================
-- 5. Missing key checks
-- Critical foreign keys and the order date must never be null.
-- =========================
SELECT
    CASE
        WHEN missing_customer_id = 0
         AND missing_product_id  = 0
         AND missing_order_date  = 0 THEN 'PASS'
        ELSE 'FAIL — null values found in critical columns'
    END AS check_result,
    missing_customer_id,
    missing_product_id,
    missing_order_date
FROM (
    SELECT
        SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS missing_customer_id,
        SUM(CASE WHEN product_id  IS NULL THEN 1 ELSE 0 END) AS missing_product_id,
        SUM(CASE WHEN order_date  IS NULL THEN 1 ELSE 0 END) AS missing_order_date
    FROM orders
);

-- =========================
-- 6. Orphaned customers check
-- Every customer_id in orders must exist in the customers table.
-- =========================
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL — orders reference customer_ids not in customers table'
    END AS check_result,
    COUNT(*) AS orphaned_customer_count
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- =========================
-- 7. Orphaned products check
-- Every product_id in orders must exist in the products table.
-- =========================
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL — orders reference product_ids not in products table'
    END AS check_result,
    COUNT(*) AS orphaned_product_count
FROM orders o
LEFT JOIN products p
    ON o.product_id = p.product_id
WHERE p.product_id IS NULL;

-- =========================
-- 8. Date logic check
-- Delivered date must never be earlier than order date.
-- =========================
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL — delivered_date is earlier than order_date on some rows'
    END AS check_result,
    COUNT(*) AS invalid_delivery_date_count
FROM orders
WHERE delivered_date < order_date;

-- =========================
-- 9. Return rate sanity check
-- Overall return rate should fall within a plausible business range (1%–30%).
-- An out-of-range figure suggests a loading or join error.
-- =========================
SELECT
    CASE
        WHEN return_rate BETWEEN 0.01 AND 0.30 THEN 'PASS'
        ELSE 'FAIL — return rate is outside expected range (1%–30%)'
    END AS check_result,
    ROUND(return_rate * 100, 2) AS return_rate_pct
FROM (
    SELECT
        COUNT(r.return_id) * 1.0 / NULLIF(COUNT(o.order_id), 0) AS return_rate
    FROM orders o
    LEFT JOIN returns r
        ON o.order_id = r.order_id
);

-- =========================
-- 10. Discount range check
-- All discounts must be between 0 and 1 (enforced by CHECK constraint,
-- but verified here as an explicit audit step).
-- =========================
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL — products have discount values outside [0, 1]'
    END AS check_result,
    COUNT(*) AS invalid_discount_count
FROM products
WHERE discount < 0
   OR discount > 1;

-- =========================
-- 11. Category conflict audit
-- Counts products where the staging layer contains more than one
-- distinct category value for the same product_id.
-- These conflicts were resolved in ETL using modal + alphabetical
-- tie-breaker, but the underlying ambiguity is flagged here for
-- visibility. A high conflict count warrants investigation at source.
-- This check is informational — it does not produce a PASS/FAIL
-- because category conflicts are a known data quality issue in the
-- source dataset, not an ETL failure.
-- =========================
SELECT
    COUNT(*)                    AS products_with_category_conflicts,
    ROUND(COUNT(*) * 100.0 /
        (SELECT COUNT(DISTINCT product_id)
         FROM staging_ecommerce), 2) AS pct_of_all_products
FROM (
    SELECT product_id
    FROM staging_ecommerce
    GROUP BY product_id
    HAVING COUNT(DISTINCT category) > 1
);
