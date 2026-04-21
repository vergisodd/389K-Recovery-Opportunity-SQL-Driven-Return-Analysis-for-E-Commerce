-- =========================
-- 04_CUSTOMER_ANALYSIS.SQL
-- Customer value, return behavior, and leakage exposure
-- =========================

-- 1. Customers driving the highest return-related loss
SELECT
    o.customer_id,
    COUNT(r.order_id) AS total_returns,
    ROUND(SUM(o.total_amount), 2) AS return_loss
FROM orders o
JOIN returns r
    ON o.order_id = r.order_id
GROUP BY o.customer_id
ORDER BY return_loss DESC, total_returns DESC
LIMIT 10;

-- 2. Highest-value customers by lifetime revenue
SELECT
    customer_id,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(total_amount), 2) AS lifetime_value
FROM orders
GROUP BY customer_id
ORDER BY lifetime_value DESC
LIMIT 10;

-- 3. Customer return behavior summary
-- Apply a minimum order threshold to reduce noise from low-activity customers
WITH customer_summary AS (
    SELECT
        o.customer_id,
        COUNT(o.order_id) AS total_orders,
        ROUND(SUM(o.total_amount), 2) AS lifetime_value,
        COUNT(r.order_id) AS return_count,
        ROUND(COUNT(r.order_id) * 1.0 / COUNT(o.order_id), 4) AS return_rate,
        ROUND(
            COALESCE(SUM(CASE WHEN r.order_id IS NOT NULL THEN o.total_amount END), 0),
            2
        ) AS return_loss
    FROM orders o
    LEFT JOIN returns r
        ON o.order_id = r.order_id
    GROUP BY o.customer_id
),
filtered AS (
    SELECT *
    FROM customer_summary
    WHERE total_orders >= 3
)
SELECT
    customer_id,
    total_orders,
    lifetime_value,
    return_count,
    return_loss,
    return_rate,
    CASE
        WHEN return_rate >= 0.50 THEN 'High Return Risk'
        WHEN return_rate >= 0.20 THEN 'Moderate Return Risk'
        ELSE 'Low Return Risk'
    END AS behavior_segment
FROM filtered
ORDER BY return_rate DESC, return_loss DESC;
