-- =========================
-- 10_TIME_ANALYSIS.SQL
-- Monthly order, revenue, and return performance
-- =========================

SELECT
    strftime('%Y-%m', o.order_date) AS month,
    COUNT(o.order_id) AS total_orders,
    COUNT(r.order_id) AS returned_orders,
    ROUND(SUM(o.total_amount), 2) AS gross_revenue,
    ROUND(
        COALESCE(SUM(CASE WHEN r.order_id IS NOT NULL THEN o.total_amount END), 0),
        2
    ) AS return_loss,
    ROUND(
        SUM(o.total_amount) -
        COALESCE(SUM(CASE WHEN r.order_id IS NOT NULL THEN o.total_amount END), 0),
        2
    ) AS net_revenue,
    ROUND(COUNT(r.order_id) * 1.0 / COUNT(o.order_id), 4) AS return_rate
FROM orders o
LEFT JOIN returns r
    ON o.order_id = r.order_id
GROUP BY strftime('%Y-%m', o.order_date)
ORDER BY month;
