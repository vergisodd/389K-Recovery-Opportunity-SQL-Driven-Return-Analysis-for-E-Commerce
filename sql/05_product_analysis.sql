-- =========================
-- 05_PRODUCT_ANALYSIS.SQL
-- Product Performance & Risk Analysis
-- =========================


-- 1. Top revenue-generating products
SELECT 
    p.product_id,
    p.category,
    SUM(o.total_amount) AS total_revenue
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.product_id, p.category
ORDER BY total_revenue DESC
LIMIT 10;


-- 2. Products with highest number of returns
SELECT 
    o.product_id,
    COUNT(r.order_id) AS return_count,
    SUM(o.total_amount) AS revenue
FROM orders o
LEFT JOIN returns r ON o.order_id = r.order_id
GROUP BY o.product_id
ORDER BY return_count DESC
LIMIT 10;


-- 3. Product return rate + risk classification (IMPORTANT)
SELECT 
    o.product_id,
    COUNT(o.order_id) AS total_orders,
    COUNT(r.order_id) AS return_orders,
    (COUNT(r.order_id) * 1.0 / COUNT(o.order_id)) AS return_rate,
    SUM(o.total_amount) AS revenue,

    CASE 
        WHEN (COUNT(r.order_id) * 1.0 / COUNT(o.order_id)) >= 0.2 THEN 'HIGH RISK'
        WHEN (COUNT(r.order_id) * 1.0 / COUNT(o.order_id)) >= 0.1 THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END AS risk_level

FROM orders o
LEFT JOIN returns r ON o.order_id = r.order_id
GROUP BY o.product_id
ORDER BY return_rate DESC;


-- 4. Products causing highest revenue loss (return impact)
SELECT 
    o.product_id,
    SUM(o.total_amount) AS total_revenue_lost
FROM orders o
JOIN returns r ON o.order_id = r.order_id
GROUP BY o.product_id
ORDER BY total_revenue_lost DESC
LIMIT 10;
