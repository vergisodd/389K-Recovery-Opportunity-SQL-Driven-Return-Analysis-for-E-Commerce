-- =========================
-- 06_CATEGORY_ANALYSIS.SQL
-- Category-level revenue, return behavior, and leakage impact
-- =========================

-- 1. Revenue by category
SELECT
    p.category,
    COUNT(o.order_id) AS total_orders,
    ROUND(SUM(o.total_amount), 2) AS total_revenue
FROM orders o
JOIN products p
    ON o.product_id = p.product_id
GROUP BY p.category
ORDER BY total_revenue DESC;

-- 2. Return rate by category
SELECT
    p.category,
    COUNT(o.order_id) AS total_orders,
    COUNT(r.order_id) AS return_orders,
    ROUND(COUNT(r.order_id) * 1.0 / COUNT(o.order_id), 4) AS return_rate
FROM orders o
JOIN products p
    ON o.product_id = p.product_id
LEFT JOIN returns r
    ON o.order_id = r.order_id
GROUP BY p.category
ORDER BY return_rate DESC, return_orders DESC;

-- 3. Return impact by category
SELECT
    p.category,
    COUNT(r.order_id) AS return_orders,
    ROUND(SUM(o.total_amount), 2) AS return_loss
FROM orders o
JOIN products p
    ON o.product_id = p.product_id
JOIN returns r
    ON o.order_id = r.order_id
GROUP BY p.category
ORDER BY return_loss DESC;

-- 4. Combined category performance summary
WITH category_summary AS (
    SELECT
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
    GROUP BY p.category
)
SELECT
    category,
    total_orders,
    return_orders,
    gross_revenue,
    return_loss,
    ROUND(return_orders * 1.0 / NULLIF(total_orders, 0), 4) AS return_rate,
    ROUND(return_loss * 1.0 / NULLIF(gross_revenue, 0), 4) AS loss_rate
FROM category_summary
ORDER BY return_loss DESC, return_rate DESC;
