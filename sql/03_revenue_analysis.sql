-- =========================
-- 03_REVENUE_ANALYSIS.SQL
-- Revenue, loss, and net recovery metrics
-- =========================

-- 1. Total gross revenue
SELECT
    ROUND(SUM(total_amount), 2) AS total_revenue
FROM orders;

-- 2. Revenue lost to returns
SELECT
    ROUND(SUM(o.total_amount), 2) AS return_loss
FROM orders o
JOIN returns r
    ON o.order_id = r.order_id;

-- 3. Net revenue after returns
SELECT
    ROUND(SUM(o.total_amount), 2) AS total_revenue,
    ROUND(
        COALESCE(SUM(CASE WHEN r.order_id IS NOT NULL THEN o.total_amount END), 0),
        2
    ) AS return_loss,
    ROUND(
        SUM(o.total_amount) -
        COALESCE(SUM(CASE WHEN r.order_id IS NOT NULL THEN o.total_amount END), 0),
        2
    ) AS net_revenue
FROM orders o
LEFT JOIN returns r
    ON o.order_id = r.order_id;

-- 4. Order-level return rate
SELECT
    ROUND(COUNT(r.order_id) * 1.0 / COUNT(o.order_id), 4) AS return_rate
FROM orders o
LEFT JOIN returns r
    ON o.order_id = r.order_id;
