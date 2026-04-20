SELECT 
    DATE_TRUNC('month', order_date) AS month,
    COUNT(*) AS total_orders,
    SUM(total_amount) AS total_revenue,
    SUM(CASE WHEN r.order_id IS NOT NULL THEN total_amount ELSE 0 END) AS returned_value
FROM orders o
LEFT JOIN returns r ON o.order_id = r.order_id
GROUP BY month
ORDER BY month;
