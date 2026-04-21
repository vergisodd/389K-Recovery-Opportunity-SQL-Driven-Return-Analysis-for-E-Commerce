-- =========================
-- 05_PRODUCT_ANALYSIS.SQL
-- Product revenue, return behavior, and leakage ranking
-- =========================

-- 1. Top revenue-generating products
SELECT
    p.product_id,
    p.category,
    COUNT(o.order_id) AS total_orders,
    ROUND(SUM(o.total_amount), 2) AS gross_revenue
FROM orders o
JOIN products p
    ON o.product_id = p.product_id
GROUP BY p.product_id, p.category
ORDER BY gross_revenue DESC
LIMIT 10;

-- 2. Products with the highest number of return orders
SELECT
    p.product_id,
    p.category,
    COUNT(r.order_id) AS return_orders,
    ROUND(
        COALESCE(SUM(CASE WHEN r.order_id IS NOT NULL THEN o.total_amount END), 0),
        2
    ) AS return_loss
FROM orders o
JOIN products p
    ON o.product_id = p.product_id
LEFT JOIN returns r
    ON o.order_id = r.order_id
GROUP BY p.product_id, p.category
ORDER BY return_orders DESC, return_loss DESC
LIMIT 10;

-- 3. Product return rate and risk classification
-- Minimum order threshold reduces noise from very low-volume products
WITH product_summary AS (
    SELECT
        p.product_id,
        p.category,
        COUNT(o.order_id) AS total_orders,
        COUNT(r.order_id) AS return_orders,
        ROUND(SUM(o.total_amount), 2) AS gross_revenue,
        ROUND(
            COALESCE(SUM(CASE WHEN r.order_id IS NOT NULL THEN o.total_amount END), 0),
            2
        ) AS return_loss
    FROM products p
    JOIN orders o
        ON p.product_id = o.product_id
    LEFT JOIN returns r
        ON o.order_id = r.order_id
    GROUP BY p.product_id, p.category
),
filtered AS (
    SELECT *
    FROM product_summary
    WHERE total_orders >= 3
)
SELECT
    product_id,
    category,
    total_orders,
    return_orders,
    gross_revenue,
    return_loss,
    ROUND(return_orders * 1.0 / NULLIF(total_orders, 0), 4) AS return_rate,
    ROUND(return_loss * 1.0 / NULLIF(gross_revenue, 0), 4) AS loss_rate,
    CASE
        WHEN return_orders * 1.0 / NULLIF(total_orders, 0) >= 0.50 THEN 'High Risk'
        WHEN return_orders * 1.0 / NULLIF(total_orders, 0) >= 0.20 THEN 'Moderate Risk'
        ELSE 'Low Risk'
    END AS risk_level
FROM filtered
ORDER BY return_rate DESC, return_loss DESC;

-- 4. Products causing the highest revenue leakage
WITH product_leakage AS (
    SELECT
        p.product_id,
        p.category,
        COUNT(o.order_id) AS total_orders,
        ROUND(SUM(o.total_amount), 2) AS gross_revenue,
        COUNT(r.order_id) AS return_orders,
        ROUND(
            COALESCE(SUM(CASE WHEN r.order_id IS NOT NULL THEN o.total_amount END), 0),
            2
        ) AS return_loss
    FROM products p
    JOIN orders o
        ON p.product_id = o.product_id
    LEFT JOIN returns r
        ON o.order_id = r.order_id
    GROUP BY p.product_id, p.category
),
filtered AS (
    SELECT *
    FROM product_leakage
    WHERE total_orders >= 3
)
SELECT
    product_id,
    category,
    total_orders,
    gross_revenue,
    return_orders,
    return_loss,
    ROUND(return_loss * 1.0 / NULLIF(gross_revenue, 0), 4) AS loss_rate,
    RANK() OVER (ORDER BY return_loss DESC) AS loss_rank
FROM filtered
ORDER BY return_loss DESC
LIMIT 10;
