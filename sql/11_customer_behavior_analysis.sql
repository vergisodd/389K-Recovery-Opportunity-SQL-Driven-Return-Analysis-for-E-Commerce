WITH customer_orders AS (
    SELECT 
        o.customer_id,
        COUNT(*) AS total_orders,
        SUM(CASE WHEN r.order_id IS NOT NULL THEN 1 ELSE 0 END) AS total_returns
    FROM orders o
    LEFT JOIN returns r 
        ON o.order_id = r.order_id
    GROUP BY o.customer_id
),
customer_behavior AS (
    SELECT 
        customer_id,
        total_orders,
        total_returns,
        total_returns * 1.0 / total_orders AS return_rate,
        CASE 
            WHEN total_returns = 0 THEN 'No Returns'
            WHEN total_returns * 1.0 / total_orders > 0.5 THEN 'High Risk'
            WHEN total_returns * 1.0 / total_orders > 0.2 THEN 'Moderate Risk'
            ELSE 'Low Risk'
        END AS risk_segment
    FROM customer_orders
)
SELECT 
    risk_segment,
    COUNT(*) AS customer_count,
    AVG(return_rate) AS avg_return_rate
FROM customer_behavior
GROUP BY risk_segment
ORDER BY avg_return_rate DESC;
